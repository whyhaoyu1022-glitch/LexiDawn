#include "MDXHTML.h"
#include <limits.h>
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
char *ld_html_attribute(void *node, const char *name) { return node ? (char *)xmlGetProp(node, (const xmlChar *)name) : NULL; }
void ld_html_free(char *text) { if (text) xmlFree(text); }
