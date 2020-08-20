%{
	// TODO: Accept Dieresis (unicode required)

	#include <ctype.h>
	#include <stdbool.h>
	#include <assert.h>
	#include "colors.h"

	#define ELEMENT_STACK_MAX        32
	#define MAX_SYLLABLE_TEMPLATES   4
	#define MAX_WORD_LENGTH          128

	typedef enum {
		TOK_VOWEL,
		TOK_CONSONANT,
		TOK_SYLLABLE
	} token_t;

	typedef struct {
		token_t token;
		const char *lexeme;
	} element_t;

	element_t *make_element (token_t, const char *);
	void push_element (element_t *);
	element_t *pop_element ();
	element_t *merge_element (token_t, element_t *, element_t *);
	void delete_element (element_t *);
	void debug_stack();
	void merge_stack();
	void dump_stack();
%}

syllable_1         (sch|sche|thie)
vowel_3            (aai|oei|ooi|eeu|ieu)
vowel_2            (aa|oo|uu|ee|ae|ai|au|ei|eu|ie|ij|oe|oi|ou|ui)
vowel_1            [aeiouAEIOU]
consonant_2        (ch|th)
consonant_1        [a-zA-Z]{-}[aeiouAEIOU]
whitespace         [ \t\n]

%%
achtig             { push_element(make_element(TOK_SYLLABLE, "ach-tig")); }
thische            { push_element(make_element(TOK_SYLLABLE, "thi-sche"));}
thisch             { push_element(make_element(TOK_SYLLABLE, "thi-sch")); }
{syllable_1}       { push_element(make_element(TOK_SYLLABLE, yytext));    }
{vowel_3}          { push_element(make_element(TOK_VOWEL, yytext));       }
{vowel_2}          { push_element(make_element(TOK_VOWEL, yytext));       }
{consonant_2}      { push_element(make_element(TOK_CONSONANT, yytext));   }
{vowel_1}          { push_element(make_element(TOK_VOWEL, yytext));       }
{consonant_1}      { push_element(make_element(TOK_CONSONANT, yytext));   }
{whitespace}       { debug_stack(); merge_stack(); dump_stack();          }
(.)                { putchar(*yytext);                                    }

%%

element_t *g_element_stack[ELEMENT_STACK_MAX];
size_t g_element_stack_size = 0;

char    g_word_char_map[MAX_WORD_LENGTH];
uint8_t g_word_syllable_offset[MAX_WORD_LENGTH];
size_t  g_word_length = 0;

void make_syllable_offset_map ()
{
	g_word_length = 0;
	for (off_t i = 0; i < g_element_stack_size; ++i) {
		element_t *element_p = g_element_stack[i];
		size_t len = strlen(element_p->lexeme);
		for (off_t j = 0; j < len; ++j) {
			g_word_char_map[g_word_length + j] = element_p->lexeme[j];
			g_word_syllable_offset[g_word_length + j] = (uint8_t)i;
		}
		g_word_length += len;
	}
}

element_t *make_element (token_t token, const char *lexeme)
{
	// Allocate new element
	element_t *element = malloc(sizeof(element_t));
	assert(element != NULL);

	// Copy lexeme
	size_t len = strlen(lexeme);
	char *copy = malloc((len + 1) * sizeof(char));
	assert(copy != NULL);
	strcpy(copy, lexeme);

	// Configure and return element
	element->token = token;
	element->lexeme = copy;
	return element;
}

// Push element to global stack; increments stack pointer
void push_element (element_t *element_p)
{
	assert(g_element_stack_size < ELEMENT_STACK_MAX);
	g_element_stack[g_element_stack_size++] = element_p;
}

// Pops element from global stack; lowers stack pointer
element_t *pop_element ()
{
	assert(g_element_stack_size > 0);
	return g_element_stack[--g_element_stack_size];
}

// Allocates new element merging two similar elements; assigns given token
element_t *merge_element (token_t token, element_t *a, element_t *b)
{
	// Validate input; compute length of merged lexeme
	assert(!(a == NULL || a->lexeme == NULL));
	assert(!(b == NULL || b->lexeme == NULL));
	size_t len = strlen(a->lexeme) + strlen(b->lexeme);

	// Create merged lexeme
	char *merged_lexeme = malloc((len + 1) * sizeof(char));
	assert(merged_lexeme != NULL);
	sprintf(merged_lexeme, "%s%s", a->lexeme, b->lexeme);

	// Obtain new element
	element_t *merged_element = make_element(token, merged_lexeme);

	// Release allocated memory
	free(merged_lexeme);

	return merged_element;
}

void delete_element (element_t *e)
{
	assert(e != NULL);
	assert(e->lexeme != NULL);
	free((char *)(e->lexeme));
	free(e);
}

void debug_stack ()
{
	element_t *element_p = NULL;

	for (off_t i = 0; i < g_element_stack_size; ++i)
	{
		element_p = g_element_stack[i];
		switch (element_p->token) {
			case TOK_VOWEL: {
				printf(C_TAF(BOL, GRN, "%s"), element_p->lexeme);
			}
			break;

			case TOK_CONSONANT: {
				printf(C_TAF(BOL, BLU, "%s"), element_p->lexeme);
			}
			break;

			case TOK_SYLLABLE: {
				printf(C_TAF(UND, YEL, "%s"), element_p->lexeme);
			}
			break;
		}
		if (i < (g_element_stack_size - 1)) {
			putchar('.');
		}
	}
	putchar('\n');
}

void merge_stack ()
{
	// Compute the offset map
	make_syllable_offset_map();

	// Print the offset map
	for (int i = 0; i < g_word_length; ++i) {
		printf("%c ", g_word_char_map[i]);
	}
	putchar('\n');
	for (int i = 0; i < g_word_length; ++i) {
		printf("%d ", g_word_syllable_offset[i]);
	}
	putchar('\n');
}

void dump_stack ()
{
	
	// Free memory; reset stack
	for (off_t i = 0; i < g_element_stack_size; ++i)
	{
		delete_element(g_element_stack[i]);
	}
	g_element_stack_size = 0;
}


int main (int argc, char *argv[])
{
	// Run lexer
	yylex();

	return EXIT_SUCCESS;
}




