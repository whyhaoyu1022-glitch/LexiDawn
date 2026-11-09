// MDX 2.0 layout: https://github.com/zhansliu/writemdict/blob/master/fileformat.md
// Bounded, seek-based implementation validated against the complete bundled file.
#include "MDXReader.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>

typedef struct { char *key; uint64_t offset; } LDKey;
typedef struct { uint64_t file_offset, start, compressed, size; } LDBlock;
struct LDMDX {
    FILE *file;
    uint64_t file_size, total_records;
    size_t key_count, block_count;
    LDKey *keys;
    LDBlock *blocks;
    size_t cached_index;
    unsigned char *cached_block;
};

static void message(char *out, size_t n, const char *text) { if (out && n) snprintf(out, n, "%s", text); }
static uint64_t big(const unsigned char *p, size_t n) {
    uint64_t value = 0;
    for (size_t i = 0; i < n; i++) value = (value << 8) | p[i];
    return value;
}
static int read_exact(LDMDX *r, unsigned char *out, size_t n) {
    off_t at = ftello(r->file);
    return at >= 0 && (uint64_t)at <= r->file_size && n <= r->file_size - (uint64_t)at && fread(out, 1, n, r->file) == n;
}
static int number(LDMDX *r, uint64_t *out) {
    unsigned char bytes[8];
    if (!read_exact(r, bytes, 8)) return 0;
    *out = big(bytes, 8); return 1;
}
static unsigned char *inflate_block(LDMDX *r, uint64_t compressed, uint64_t size) {
    // Cap each allocation before conversion to size_t/uLong; defend corrupt headers.
    if (compressed < 8 || compressed > 16 * 1024 * 1024 || size > 32 * 1024 * 1024) return NULL;
    unsigned char *input = malloc((size_t)compressed), *output = malloc((size_t)size + 1);
    if (!input || !output || !read_exact(r, input, (size_t)compressed)) { free(input); free(output); return NULL; }
    int valid = 0;
    if (memcmp(input, "\0\0\0\0", 4) == 0 && compressed - 8 == size) {
        memcpy(output, input + 8, (size_t)size); valid = 1;
    } else if (memcmp(input, "\2\0\0\0", 4) == 0) {
        uLongf length = (uLongf)size;
        valid = uncompress(output, &length, input + 8, (uLong)(compressed - 8)) == Z_OK && length == size;
    }
    if (valid) valid = adler32(1L, output, (uInt)size) == big(input + 4, 4);
    free(input);
    if (!valid) { free(output); return NULL; }
    output[size] = 0; return output;
}

void ld_mdx_close(LDMDX *r) {
    if (!r) return;
    if (r->file) fclose(r->file);
    if (r->keys) for (size_t i = 0; i < r->key_count; i++) free(r->keys[i].key);
    free(r->keys); free(r->blocks); free(r->cached_block); free(r);
}
size_t ld_mdx_count(const LDMDX *r) { return r ? r->key_count : 0; }
const char *ld_mdx_key(const LDMDX *r, size_t i) { return r && i < r->key_count ? r->keys[i].key : NULL; }
void ld_mdx_free(void *p) { free(p); }

LDMDX *ld_mdx_open(const char *path, char *error, size_t error_capacity) {
    LDMDX *r = calloc(1, sizeof(*r));
    unsigned char *header = NULL, *index = NULL, *block = NULL;
    uint64_t *key_sizes = NULL;
    const char *failure = "MDX structure or checksum is invalid";
    if (!r) { message(error, error_capacity, "MDX allocation failed"); return NULL; }
    r->cached_index = SIZE_MAX;
    r->file = fopen(path, "rb");
    if (!r->file) { failure = "MDX resource could not be opened"; goto fail; }
    if (fseeko(r->file, 0, SEEK_END) || ftello(r->file) < 8) goto fail;
    r->file_size = (uint64_t)ftello(r->file);
    if (fseeko(r->file, 0, SEEK_SET)) goto fail;
    unsigned char small[40];
    if (!read_exact(r, small, 4)) goto fail;
    uint64_t header_size = big(small, 4);
    if (header_size < 2 || header_size > 1024 * 1024 || header_size % 2) goto fail;
    header = malloc((size_t)header_size + 1);
    if (!header || !read_exact(r, header, (size_t)header_size) || !read_exact(r, small, 4)) goto fail;
    uint32_t header_checksum = (uint32_t)small[0] | (uint32_t)small[1] << 8 | (uint32_t)small[2] << 16 | (uint32_t)small[3] << 24;
    if (adler32(1L, header, (uInt)header_size) != header_checksum) goto fail;
    // Header XML is UTF-16LE independently of the payload Encoding attribute.
    for (size_t i = 0; i < header_size / 2; i++) header[i] = header[i * 2 + 1] ? '?' : header[i * 2];
    header[header_size / 2] = 0;
    if (!strstr((char *)header, "RequiredEngineVersion=\"2.0\"") ||
        !strstr((char *)header, "Encoding=\"UTF-8\"") ||
        !(strstr((char *)header, "Encrypted=\"No\"") || strstr((char *)header, "Encrypted=\"0\""))) {
        failure = "Unsupported MDX version, encoding or encryption"; goto fail;
    }
    free(header); header = NULL;
    if (!read_exact(r, small, 40)) goto fail;
    uint64_t key_blocks = big(small, 8), key_count = big(small + 8, 8), index_size = big(small + 16, 8),
             index_compressed = big(small + 24, 8), keys_compressed = big(small + 32, 8);
    uint32_t key_checksum = (uint32_t)adler32(1L, small, 40);
    if (!read_exact(r, small, 4) || big(small, 4) != key_checksum || !key_blocks || key_blocks > 100000 || !key_count || key_count > 2000000) goto fail;
    r->key_count = (size_t)key_count;
    r->keys = calloc(r->key_count, sizeof(*r->keys));
    key_sizes = calloc((size_t)key_blocks * 3, sizeof(*key_sizes));
    if (!r->keys || !key_sizes) goto fail;
    index = inflate_block(r, index_compressed, index_size);
    if (!index) goto fail;
    size_t cursor = 0; uint64_t declared_keys = 0, compressed_sum = 0;
    for (size_t i = 0; i < key_blocks; i++) {
        if (cursor > index_size || index_size - cursor < 8) goto fail;
        uint64_t count = big(index + cursor, 8); cursor += 8;
        key_sizes[i * 3 + 2] = count; declared_keys += count;
        for (int boundary = 0; boundary < 2; boundary++) {
            if (index_size - cursor < 2) goto fail;
            size_t length = (size_t)big(index + cursor, 2); cursor += 2;
            if (index_size - cursor < length + 1 || index[cursor + length] != 0) goto fail;
            cursor += length + 1;
        }
        if (index_size - cursor < 16) goto fail;
        key_sizes[i * 3] = big(index + cursor, 8); key_sizes[i * 3 + 1] = big(index + cursor + 8, 8);
        compressed_sum += key_sizes[i * 3]; cursor += 16;
    }
    if (cursor != index_size || declared_keys != key_count || compressed_sum != keys_compressed) goto fail;
    free(index); index = NULL;
    size_t key_position = 0;
    for (size_t i = 0; i < key_blocks; i++) {
        uint64_t size = key_sizes[i * 3 + 1];
        block = inflate_block(r, key_sizes[i * 3], size);
        if (!block) goto fail;
        cursor = 0;
        for (uint64_t j = 0; j < key_sizes[i * 3 + 2]; j++) {
            if (cursor > size || size - cursor < 9 || key_position >= r->key_count) goto fail;
            uint64_t offset = big(block + cursor, 8); cursor += 8;
            unsigned char *end = memchr(block + cursor, 0, (size_t)size - cursor);
            if (!end) goto fail;
            size_t length = (size_t)(end - (block + cursor));
            char *key = malloc(length + 1);
            if (!key) goto fail;
            memcpy(key, block + cursor, length); key[length] = 0;
            r->keys[key_position].key = key; r->keys[key_position].offset = offset;
            if (key_position && offset < r->keys[key_position - 1].offset) goto fail;
            key_position++; cursor += length + 1;
        }
        if (cursor != size) goto fail;
        free(block); block = NULL;
    }
    free(key_sizes); key_sizes = NULL;
    uint64_t records, entries, info_size, record_compressed;
    if (!number(r, &records) || !number(r, &entries) || !number(r, &info_size) || !number(r, &record_compressed) ||
        !records || records > 1000000 || entries != key_count || info_size != records * 16) goto fail;
    r->block_count = (size_t)records;
    r->blocks = calloc(r->block_count, sizeof(*r->blocks));
    if (!r->blocks) goto fail;
    uint64_t start = 0, file_offset = (uint64_t)ftello(r->file) + info_size;
    compressed_sum = 0;
    for (size_t i = 0; i < r->block_count; i++) {
        uint64_t compressed, size;
        if (!number(r, &compressed) || !number(r, &size) || compressed < 8 || compressed > 16 * 1024 * 1024 || size > 32 * 1024 * 1024 ||
            file_offset > r->file_size || compressed > r->file_size - file_offset || start > UINT64_MAX - size) goto fail;
        r->blocks[i] = (LDBlock){file_offset, start, compressed, size};
        file_offset += compressed; start += size; compressed_sum += compressed;
    }
    r->total_records = start;
    if (compressed_sum != record_compressed || file_offset != r->file_size || key_position != r->key_count || r->keys[r->key_count - 1].offset > start) goto fail;
    return r;
fail:
    free(header); free(index); free(block); free(key_sizes); ld_mdx_close(r);
    message(error, error_capacity, failure); return NULL;
}

int ld_mdx_record(LDMDX *r, size_t index, unsigned char **bytes, size_t *length, char *error, size_t capacity) {
    if (bytes) *bytes = NULL;
    if (length) *length = 0;
    if (!r || !bytes || !length || index >= r->key_count) { message(error, capacity, "MDX entry index is invalid"); return 0; }
    uint64_t start = r->keys[index].offset;
    uint64_t end = index + 1 < r->key_count ? r->keys[index + 1].offset : r->total_records;
    if (end < start || end - start > 8 * 1024 * 1024) { message(error, capacity, "MDX entry bounds are invalid"); return 0; }
    unsigned char *out = malloc((size_t)(end - start) + 1);
    if (!out) { message(error, capacity, "MDX allocation failed"); return 0; }
    size_t written = 0;
    // Binary search the first block containing this decompressed offset.
    size_t lower = 0, upper = r->block_count;
    while (lower < upper) { size_t middle = lower + (upper - lower) / 2; if (r->blocks[middle].start + r->blocks[middle].size <= start) lower = middle + 1; else upper = middle; }
    for (size_t i = lower; i < r->block_count && r->blocks[i].start < end; i++) {
        LDBlock b = r->blocks[i];
        if (r->cached_index != i) {
            if (fseeko(r->file, (off_t)b.file_offset, SEEK_SET)) goto fail;
            unsigned char *decoded = inflate_block(r, b.compressed, b.size);
            if (!decoded) goto fail;
            free(r->cached_block); r->cached_block = decoded; r->cached_index = i;
        }
        uint64_t from = start > b.start ? start - b.start : 0;
        uint64_t to = end - b.start < b.size ? end - b.start : b.size;
        if (to < from || written + to - from > end - start) goto fail;
        memcpy(out + written, r->cached_block + from, (size_t)(to - from)); written += (size_t)(to - from);
    }
    if (written != end - start) goto fail;
    out[written] = 0; *bytes = out; *length = written; return 1;
fail:
    free(out); message(error, capacity, "MDX record decompression, checksum or bounds failed"); return 0;
}
