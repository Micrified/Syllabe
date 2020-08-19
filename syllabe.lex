%{
    // Include
    #include <ctype.h>

    // Symbolic constants
    #define MAX_WORD_LENGTH			128

	// Type definitions
	typedef enum {
		TOK_VOWEL,
		TOK_CONSONANT,
		TOK_PREFIX,
		TOK_SUFFIX,
		TOK_WHITESPACE,
		TOK_OTHER
	} token_t;

	typedef enum {
		STATE_ECHO,
		STATE_WORD
	} state_t;

	// Forward declarations
	void push_word (token_t, char);
	void naar_syllaben (size_t, char *, token_t *);
%}

vowel					[aeiouAEIOU]
consonant				[a-zA-Z]{-}[aeiouAEIOU]
whitespace          	[ \t\n]

%%

(be|er|ge|her|ont|ver)                        { push_token(TOK_PREFIX, yytext);     }
(isch|ische|thie|thisch|thische|achtig)       { push_token(TOK_SUFFIX, yytext);     }
{vowel}			         { push_token(TOK_VOWEL, yytext);      }
(ch|rts|mbt|lfts|rwt)    { push_token(TOK_CONSONANT, yytext);  }
{consonant}		         { push_word(TOK_CONSONANT, *yytext);  }
{whitespace}             { push_word(TOK_WHITESPACE, *yytext); } 
(.)						 { putchar(*yytext);                   }

%% 

void push_word (token_t t, char c)
{
	static char    cs[MAX_WORD_LENGTH];
	static token_t ts[MAX_WORD_LENGTH];
	static size_t len = 0;

	if (len >= MAX_WORD_LENGTH)
	{
		// TODO: Handle words that are too long
		printf("[?]");
		goto reset;
	}

	if (t == TOK_VOWEL || t == TOK_CONSONANT)
	{
		cs[len] = c; ts[len] = t; len++;
		return;
	}

	if (len > 0)
	{
		naar_syllaben(len, cs, ts);
reset:
		len = 0;
	} else {
		putchar(c);
	}

}

void naar_syllaben (size_t len, char *cs, token_t *ts)
{
	off_t i = 0, j, n;

	// Convert to syllables
	while (1)
	{
		// Dump the rest if there are less than 3 letters 
		if (len - i <= 3) {
			while (i < len) {
				putchar(cs[i++]);
			}
			goto end;
		}

		// Dump consonants until first vowel
		for (; i < len && ts[i] != TOK_VOWEL; putchar(cs[i]), ++i);

		// Check: End of word? 
		if (i >= len) break;

		// Put the vowel, increment counter
		putchar(cs[i]); ++i;

		// Check: End of word? 
		if (i >= len) break;

		// Find occurrence of next vowel
		for (j = i; j < len && ts[j] != TOK_VOWEL; ++j);

		// Compute: Number of consonants between
		n = (j - i);

		// Case: None 
		if (n == 0)
		{
			// TODO: double vowel (should be handled by lexer)

			continue;
		}

		// Case: One
		if (n == 1)
		{
			// Rule #1: Consonant forms beginning of next syllable
			goto next;
		}

		// Case: Two or more
		if (n > 1)
		{
			// Rule #2: First syllable gets one consonant; second rest
			putchar(cs[i]); i++;
			goto next;
		}
next:
		putchar('-');
	}
end:
	putchar('\n');
}

int main (int argc, char *argv[])
{
	// Run lexer
	yylex();

	return EXIT_SUCCESS;
}