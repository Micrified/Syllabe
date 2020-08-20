%{
    // Include
    #include <ctype.h>
    #include <stdbool.h>
    #include "colors.h"

    // Symbolic constants
    #define MAX_ELEMENT_COUNT       8
    #define MAX_LEXEME_LENGTH       16

	// Type definitions
	typedef enum {
		TOK_VOWEL,
		TOK_VOWEL_DUPLO,
		TOK_CONSONANT_NORM,
		TOK_CONSONANT_HARD,
		TOK_PREFIX,
		TOK_SUFFIX,
		TOK_WS
	} token_t;

	typedef struct {
		token_t token;
		char lexeme[MAX_LEXEME_LENGTH];
	} elem_t;

	// Forward declarations
	void push_token (token_t, const char *);
	size_t accept_word (size_t, elem_t *);
	size_t accept_syllable (size_t, elem_t *);
%}

vowel                                         [aeiouAEIOU]
consonant                                     [a-zA-Z]{-}[aeiouAEIOU]
whitespace                                    [ \t\n]


%%


(isch|ische|thie|thisch|thische|achtig)       { push_token(TOK_SUFFIX, yytext);          }
(be|er|ge|her|ont|ver)                        { push_token(TOK_PREFIX, yytext);          }
(aai|oei|ooi|eeu|ieu)                         { push_token(TOK_VOWEL, yytext);           }
(aa|oo|uu)                                    { push_token(TOK_VOWEL_DUPLO, yytext);     }
(ee|ae|ai|au|ei|eu|ie|ij|oe|oi|ou|ui)         { push_token(TOK_VOWEL, yytext);           }
(rts|mbt|lfts|rwt)                            { push_token(TOK_CONSONANT_HARD, yytext);  }
ch                                            { push_token(TOK_CONSONANT_NORM, yytext);  }
{vowel}                                       { push_token(TOK_VOWEL, yytext);           }
{consonant}                                   { push_token(TOK_CONSONANT_NORM, yytext);  }
{whitespace}                                  { push_token(TOK_WS, NULL);                }
(.)                                           { putchar(*yytext);                        }


%%

// TODOs
// 1. Prefixes may appear inside, so always apply them as a second phase
// 2. Consonants that should be grouped with the previous syllable ought not to be tokens
// 3. Rule to make isch(e) a suffix (as own syllable) too inprecise. Use sch(e) as own syllable
void push_token (token_t token, const char *lexeme)
{
	static elem_t elements[MAX_ELEMENT_COUNT];
	static size_t element_count = 0;

	// Must push all tokens if not whitespace (signals end of word)
	if (token != TOK_WS)
	{
		// Remains space in elements?
		if (element_count >= MAX_ELEMENT_COUNT)
		{
			// TODO: Handle words that are too long
			fprintf(stderr, "(skipping oversized word)\n");
			return;
		}

		// Can copy lexeme? 
		if (strlen(lexeme) >= MAX_LEXEME_LENGTH)
		{
			// TODO: Handle lexemes that exceed length
			fprintf(stderr, "(skipping word with oversized lexeme)\n");
			return;
		}

		// Install element
		elements[element_count].token = token;
		strncpy(elements[element_count].lexeme, lexeme, MAX_LEXEME_LENGTH);

		// Increment element count
		element_count++;

		return;
	}

	// On whitespace: Process sequence
	for (int k = 0; k < element_count; ++k) {
		printf("%s.", elements[k].lexeme);
	} printf(" -> ");

	accept_word (element_count, elements);

	// Push the whitespace
	// printf("%s", lexeme);
	putchar('\n');

	// Reset
	element_count = 0;
}


size_t accept_word (size_t element_count, elem_t *elements)
{
	size_t i, r, n = 0;

	// Required: Nonzero elements
	if (element_count == 0) { return 0; };

	// Optional: Accept prefix
	if (elements[n].token == TOK_PREFIX)
	{
		printf("%s", elements[n].lexeme);
		n++;
	}

	// Required: Nonzero normal syllables
	if (n == element_count) { return 0; }

	// If there was a prefix, add separator
	if (n > 0) { putchar('-'); }

	// Optional: Accept zero or more standard syllables
	while (n < (element_count - 1))
	{
		if ((r = accept_syllable(element_count - n, elements + n)) != 0)
		{
			for (i = n; i < n + r; ++i) { printf("%s", elements[i].lexeme); }
			n += r;
			if (n < (element_count - 1)) putchar('-');
		} else {
			break;
		}
	}

	// Optional: Accept final standard syllable
	if ((r = accept_syllable(element_count - n, elements + n)) != 0)
	{
		for (i = n; i < n + r; ++i) { printf("%s", elements[i].lexeme); }
		n += r;
	} else if (elements[n].token == TOK_SUFFIX) {
		printf("%s", elements[n].lexeme);
		n++;
	}

	return n;
}

size_t accept_syllable (size_t element_count, elem_t *elements)
{
	size_t i, n = 0;

	// Required: nonzero elements
	if (element_count == 0) { return 0; }

	// Accept zero or more normal consonants
	while (n < element_count && elements[n].token == TOK_CONSONANT_NORM) {
		n++;
	}

	// Required: At least a vowel
	if ((n >= element_count) || 
	    !(elements[n].token == TOK_VOWEL || elements[n].token == TOK_VOWEL_DUPLO))
	{
		return 0;
	} else {
		n++;
	}

	// If nothing after, simply return now
	if (n >= element_count) {
		return n;
	}

	// Otherwise locate next vowel or reach the end
	for (i = n; i < element_count && 
	     !(elements[i].token == TOK_VOWEL || elements[n].token == TOK_VOWEL_DUPLO); ++i)
	{
		// If we hit a suffix then break now
		if (elements[i].token == TOK_SUFFIX) {
			break;
		}
	}

	// If reached the end: no vowels or suffixes. Just return total as syllable
	if (i >= element_count)
	{
		return element_count;
	}

	// Otherwise: Could have been a suffix. In this case return too
	if (elements[i].token == TOK_SUFFIX)
	{
		return i;
	}

	// Finally: Must be another vowel -> compute number of consonants between
	off_t consonant_count = i - n;

	// If one consonant, push to the next (unless it is a hard one)
	if (consonant_count == 1)
	{

		// If consonant is hard, keep it
		if (elements[n + 1].token == TOK_CONSONANT_HARD)
		{
			n++;
		}
	}

	// If more than one consonant, keep one and push the others
	if (consonant_count > 1)
	{
		n++;
	}

	return n;
}

int main (int argc, char *argv[])
{
	// Run lexer
	yylex();

	return EXIT_SUCCESS;
}