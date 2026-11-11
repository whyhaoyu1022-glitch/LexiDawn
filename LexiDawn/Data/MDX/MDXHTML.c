#include "MDXHTML.h"
#include <limits.h>
#include <ctype.h>
#include <string.h>
#include <libxml/HTMLparser.h>
#include <libxml/tree.h>

void *ld_html_parse(const char *bytes, size_t length) {
    if (!bytes || !length || length > 4 * 1024 * 1024 || length > INT_MAX) return NULL;
    // No network/entity substitution, CSS, media, JavaScript, or WebView execution.
    return htmlReadMemory(bytes, (int)length, NULL, "UTF-8",
        HTML_PARSE_RECOVER | HTML_PARSE_NONET | HTML_PARSE_NOERROR | HTML_PARSE_NOWARNING | HTML_PARSE_COMPACT);
}
void ld_html_close(void *document) { if (document) xmlFreeDoc(document); }
void *ld_html_root(void *document) { return document ? xmlDocGetRootElement(document) : NULL; }
static xmlNodePtr element(xmlNodePtr node) {
    while (node && node->type != XML_ELEMENT_NODE) node = node->next;
    return node;
}
void *ld_html_child(void *node) { return node ? element(((xmlNodePtr)node)->children) : NULL; }
void *ld_html_next(void *node) { return node ? element(((xmlNodePtr)node)->next) : NULL; }
void *ld_html_parent(void *node) {
    xmlNodePtr parent = node ? ((xmlNodePtr)node)->parent : NULL;
    return parent && parent->type == XML_ELEMENT_NODE ? parent : NULL;
}
char *ld_html_text(void *node) { return node ? (char *)xmlNodeGetContent(node) : NULL; }
static int homonym_marker(xmlNodePtr node) {
    xmlChar *classes = xmlGetProp(node, (const xmlChar *)"class");
    if (!classes) return 0;
    const char *cursor = (const char *)classes;
    int skip = 0;
    while (*cursor) {
        while (*cursor && isspace((unsigned char)*cursor)) cursor++;
        const char *start = cursor;
        while (*cursor && !isspace((unsigned char)*cursor)) cursor++;
        size_t length = (size_t)(cursor - start);
        if ((length == 4 && memcmp(start, "t-hm", 4) == 0) ||
            (length == 9 && memcmp(start, "t-homonym", 9) == 0)) { skip = 1; break; }
    }
    xmlFree(classes);
    return skip;
}
static int append_headword(xmlNodePtr node, xmlBufferPtr buffer) {
    if (node->type == XML_TEXT_NODE || node->type == XML_CDATA_SECTION_NODE)
        return !node->content || xmlBufferAdd(buffer, node->content, -1) == 0;
    if (node->type != XML_ELEMENT_NODE || homonym_marker(node)) return 1;
    for (xmlNodePtr child = node->children; child; child = child->next)
        if (!append_headword(child, buffer)) return 0;
    return 1;
}
char *ld_html_headword(void *node) {
    if (!node) return NULL;
    xmlBufferPtr buffer = xmlBufferCreate();
    if (!buffer) return NULL;
    char *result = append_headword((xmlNodePtr)node, buffer) ? (char *)xmlStrdup(xmlBufferContent(buffer)) : NULL;
    xmlBufferFree(buffer);
    return result;
}
char *ld_html_attribute(void *node, const char *name) { return node ? (char *)xmlGetProp(node, (const xmlChar *)name) : NULL; }
void ld_html_free(char *text) { if (text) xmlFree(text); }
