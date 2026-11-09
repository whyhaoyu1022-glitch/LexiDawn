#ifndef LEXIDAWN_MDX_READER_H
#define LEXIDAWN_MDX_READER_H
#include <stddef.h>

// Reader for the verified bundled MDX 2.0 (unencrypted UTF-8; raw/zlib blocks).
// Unsupported metadata/compression fails explicitly. Caller serializes access.
typedef struct LDMDX LDMDX;
LDMDX *ld_mdx_open(const char *path, char *error, size_t error_capacity);
void ld_mdx_close(LDMDX *reader);
size_t ld_mdx_count(const LDMDX *reader);
const char *ld_mdx_key(const LDMDX *reader, size_t index);
int ld_mdx_record(LDMDX *reader, size_t index, unsigned char **bytes, size_t *length,
                  char *error, size_t error_capacity);
void ld_mdx_free(void *bytes);
#endif
