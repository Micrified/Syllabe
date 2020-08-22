# Syllabe

A program using Flex to decompose ASCII encoded Dutch words into constituent syllables

# Installation

Install Flex, then simple run `make` in the cloned directory. 

# Execution

The program expects words to come through `stdin`. This may be piped into `a.out` via an input file (`./a.out < words.txt`)

# Syllable Formation Rules
The following (sometimes conflicting) rules are used for syllable creation. This section also covers rules that were not implemented, and rules that might be possible to implement in the future. 


### Rules - implemented 

1. If two vowels are separated by a single consonant, then the consonant forms the beginning of the next syllable
2. If two vowels are separated by more than one consonant, the first consonant is combined with the vowel, and the rest pushed to the next syllable
3. Consonant combination `ch` is considered a single consonant
4. Word prefixes (`be`, `ge`, `er`, `her`, `ont`, `ver`) form their own distinct syllables
5. Word suffixes (`sch`, `sche`, `thie`, `thisch`, `thische`, `achtig`) are considered their own syllables
6. Double vowels (including subset of duplo vowels) are combined (`aa`, `ee`, `oo`, `uu`, `ae`, `ai`, `au`, `ei`, `eu`, `ie`, `ij`, `oe`, `oi`, `ou`, `ui`). The set of triple vowels (`aai`, `oei`, `ooi`, `eeu`, `ieu`) are also combined


### Rules - unimplemented

1. Compound words are split at the boundaries of the constituent words (`waarom` -> `waar-om`, not `waa-rom`). This is not implemented because compound words cannot be derived. 
2. Syllables that begin with difficult to pronounce consonants are grouped with the preceding syllables (`koortsig` -> `koort-sig` and not `koor-tsig`). This is not implemented because applying pattern matching rules conflicted with other ruels. 
3. Syllables are not correctly split by dieresis. This is because no support exists for dieresis. The program only accepts ASCII input

### Inconsistencies

There exist inconsistencies in the way rules are applied to correctly decompose words into syllables in Dutch. For example, the word `besturen` is said to be decomposed into `be.stu.ren`, given that prefix `be` is its own syllable. However, in the case of `Belgische`, the form `be-lgis-sche` is incorrect. And therefore a precedence in grouping difficult to pronounce consonants with previous syllables applies here. However, how precedence works here is unclear. 
