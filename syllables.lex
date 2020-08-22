%{
	// TODO: Accept Dieresis (unicode required)
	// TODO: Decompose difficult syllables according to known rules post-formation
	// TODO: Memory leak detection
	// NOTE: The 'be' prefix doesn't always apply (see be-stu-ren vs bel-gi-sche)
	// NOTE: No support for compound words

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
	bool merge_syllables();
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
achtig             { push_element(make_element(TOK_SYLLABLE, "ach.tig")); }
thische            { push_element(make_element(TOK_SYLLABLE, "thi.sche"));}
thisch             { push_element(make_element(TOK_SYLLABLE, "thi.sch")); }
{syllable_1}       { push_element(make_element(TOK_SYLLABLE, yytext));    }
{vowel_3}          { push_element(make_element(TOK_VOWEL, yytext));       }
{vowel_2}          { push_element(make_element(TOK_VOWEL, yytext));       }
{consonant_2}      { push_element(make_element(TOK_CONSONANT, yytext));   }
{vowel_1}          { push_element(make_element(TOK_VOWEL, yytext));       }
{consonant_1}      { push_element(make_element(TOK_CONSONANT, yytext));   }
{whitespace}       { debug_stack(); merge_stack(); debug_stack(); putchar('\n'); dump_stack(); }
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


// Merges child into parent (destroys child); updates parent with given token
element_t *merge_from_right (token_t token, element_t *parent, element_t *child)
{
	// Validate input; compute length of merged lexeme
	assert(!(parent == NULL || parent->lexeme == NULL));
	assert(!(child == NULL || child->lexeme == NULL));
	size_t len = strlen(parent->lexeme) + strlen(child->lexeme);

	// Create merged lexeme (child goes before parent since merging from right)
	char *merged_lexeme = malloc((len + 1) * sizeof(char));
	assert(merged_lexeme != NULL);
	sprintf(merged_lexeme, "%s%s", child->lexeme, parent->lexeme);

	// Free the old parent lexeme
	free((char *)parent->lexeme);

	// Assign the new lexeme
	parent->lexeme = merged_lexeme;

	// Destroy the child element
	delete_element(child);

	// Update the token type
	parent->token = token;

	return parent;
}

void merge_range (token_t token, off_t l_bound, off_t u_bound)
{
	element_t **temp_buffer = NULL;
	off_t temp_buffer_ptr = 0;

	// Bound checks
	assert(l_bound <= u_bound);
	assert(l_bound >= 0 && u_bound < g_element_stack_size);

	// Check: Same element
	if (l_bound == u_bound) {
		g_element_stack[l_bound]->token = token;
		return;
	}

	// Compute number of elements to hold
	size_t n_elements_to_hold = g_element_stack_size - u_bound;

	// Allocate a copy buffer
	temp_buffer = malloc(n_elements_to_hold * sizeof(element_t *));
	assert(temp_buffer != NULL);

	// Remove until top bound
	while (g_element_stack_size > (u_bound + 1)) {
		temp_buffer[temp_buffer_ptr++] = pop_element();
	}

	// Next is top bound
	element_t *parent = pop_element();

	// Until bottom bound, merge elements into it
	while (g_element_stack_size > l_bound)
	{
		element_t *child = pop_element();
		merge_from_right(token, parent, child);
	}

	// Push merged back onto stack
	push_element(parent);

	// Return all other elements
	for (off_t i = temp_buffer_ptr; i > 0; --i) {
		push_element(temp_buffer[i - 1]);
	}

	// Destroy the temporary buffer
	free(temp_buffer);
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
	static const char *prefixes[] = {"be", "er", "ge", "her", "ont", "ver"};
	size_t n_prefixes             = sizeof(prefixes) / sizeof(const char *);
	bool can_merge_more           = false;

	// Compute the offset map
	make_syllable_offset_map();

	// Find and merge prefixes into syllables (isn't always correct)
	for (off_t i = 0; i < n_prefixes; ++i) {
		size_t prefix_len = strlen(prefixes[i]);

		// If a prefix matches
		if (strncmp(prefixes[i], g_word_char_map, prefix_len) == 0) {

			// Find the number of elements to merge
			uint8_t n_merge = g_word_syllable_offset[prefix_len - 1];

			// Letters that appear beyond should be independent
			if (g_word_syllable_offset[prefix_len] == g_word_syllable_offset[prefix_len -1]) {
				break;
			}

			// Do the merge
			merge_range (TOK_SYLLABLE, 0, n_merge);
			break;
		}
	}

	// Merge syllables according to rules
	do {
		can_merge_more = merge_syllables();
	} while (can_merge_more);
}

// Try to merge syllables along stack according to these rules
// 1. If two vowels are separated by one consonant -> consonant forms beginning of next syllable
// 2. If two vowels are separated by more than one consonant -> first vowel gets first consonant
//    the rest form a new syllable with the second
// 3. Syllable types may not be merged with other vowels or consonants
bool merge_syllables ()
{
	off_t i, j, n, l_bound, u_bound;
	bool needs_merge = false;

	// Objective: Find next consonant or vowel (skip syllables)
	for (i = 0; (i < g_element_stack_size) && (g_element_stack[i]->token == TOK_SYLLABLE); ++i);

	// Case: None found -> nothing left to do
	if (i >= g_element_stack_size) { return needs_merge; }

	// Case: A consonant or vowel was found
	l_bound = i;

	// Objective: Find the first vowel (but do not cross syllables)
	while (i < g_element_stack_size && 
	      (g_element_stack[i]->token != TOK_VOWEL && g_element_stack[i]->token != TOK_SYLLABLE)) {
		i++;
	}

	// Case: If nothing found, or a syllable found: merge now
	if (i >= g_element_stack_size || g_element_stack[i]->token == TOK_SYLLABLE) {
		printf("2. Not found or syllable found!\n");
		u_bound = i - 1;
		goto merge;
	}

	// Result: A vowel was found, and it resides at index i

	// Objective: Find next vowel, but don't across syllables to find one
	for (j = i + 1; j < g_element_stack_size && 
	    (g_element_stack[j]->token != TOK_VOWEL && g_element_stack[j]->token != TOK_SYLLABLE); 
		++j);

	// Case: j ran out of bounds -> no vowel or syllable found
	if (j >= g_element_stack_size) {
		u_bound = j - 1;
		goto merge;
	}

	// Case: j is in bounds, but found a syllable -> merge early
	if (g_element_stack[j]->token == TOK_SYLLABLE) {
		u_bound = j - 1;
		goto merge;
	}

	// Result: Must be vowel; Action: Depends on number of consonants between them
	n = (j - i - 1);

	// Case: No or one consonant -> push remainder to next syllable
	if (n <= 1) {
		u_bound = i;
	} else {
	// Case: More than one       -> take first consonant, push remainder
		u_bound = i + 1;
	}

	// Merge elements into syllables
merge:
	merge_range (TOK_SYLLABLE, l_bound, u_bound);

	// Return whether more remains to be checked
	return (u_bound < g_element_stack_size);
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