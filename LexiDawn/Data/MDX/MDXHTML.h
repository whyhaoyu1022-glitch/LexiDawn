#ifndef LEXIDAWN_MDX_HTML_H
#define LEXIDAWN_MDX_HTML_H
#include <stddef.h>
// Opaque wrappers keep libxml2's implementation structs out of Swift.
void *ld_html_parse(const char *bytes, size_t length);
void ld_html_close(void *document);
void *ld_html_root(void *document);
void *ld_html_child(void *node);
void *ld_html_next(void *node);
void *ld_html_parent(void *node);
char *ld_html_text(void *node);
char *ld_html_attribute(void *node, const char *name);
void ld_html_free(char *text);
#endif
