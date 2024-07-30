import FlutterMacOS
import Foundation
import AppKit

/// Plugin to check spelling errors in text using the native macOS spell checker.
public class SuperEditorSpellcheckPlugin: SpellCheckApi {

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = SuperEditorSpellcheckPlugin()
    SpellCheckApiSetup.setUp(binaryMessenger: registrar.messenger, api: instance)
  }

  /// Checks the given `text` for spelling errors with the given `language`.
  ///
  /// Returns a list of `TextSuggestion`s, where each entry represents a
  /// misspelled word, with the possible suggestions.
  ///
  /// Returns an empty list if no spelling errors are found or if the `language`
  /// isn't supported by the spell checker.
  func fetchSuggestions(text: String, language: String) throws -> [TextSuggestion] {
    var result : [TextSuggestion] = [];

    if (text.isEmpty) {
      // We can't look for misspelled words without a text.
      return result;
    }

    if (language.isEmpty) {
      throw PigeonError(code: "missing_language", message: "The argument 'language' must not be empty", details: "");
    }

    let spellChecker = NSSpellChecker.shared;
    
    var languageCode = language.replacingOccurrences(of: "-", with: "_")
    if (!spellChecker.availableLanguages.contains(languageCode)){
      // The given language isn't supported by the spell checker. It might be the case that
      // the user has a language configured with an incompatible region. For example,
      // a user might have "en-BR" configured, which means that the language is English,
      // but the region is Brazil. In this case, we should try to use only the language.
      let firstPart = languageCode.components(separatedBy: "_").first;
      if (firstPart == nil) {
        // The language code isn't in the format language_REGION. Fizzle.
        return result;
      }

      languageCode = firstPart!;
      if (!spellChecker.availableLanguages.contains(languageCode)){
        // The given language isn't supported by the spell checker. Fizzle.
        return result;
      }
    }

    // The start of the substring we are looking at.
    var currentOffset = 0;
    while (currentOffset < text.count) {
      let misspelledRange = spellChecker.checkSpelling(
        of: text,
        startingAt: currentOffset,
        language: languageCode,
        wrap: false,
        inSpellDocumentWithTag: 0,
        wordCount: nil
      );

      if (misspelledRange.location == NSNotFound) {
        // There are no more misspelled words in the text.
        break;
      }

      // We found a misspeled word. Check for suggestions.
      let guesses = spellChecker.guesses(
        forWordRange: misspelledRange,
        in: text,
        language: languageCode,
        inSpellDocumentWithTag: 0
      );

      // Only append the suggestion span if we have suggestions.
      // It wouldn't help to return a misspelled word without suggestions.
      if (guesses?.isEmpty == false) {
        result.append(TextSuggestion(
          start: Int64(misspelledRange.location),
          // Transform the end to be exclusive, to match the Dart TextRange.
          end: Int64(misspelledRange.location + misspelledRange.length),
          suggestions: guesses!
        ));
      }

      // Place the offset after the current word to continue the search.
      currentOffset += misspelledRange.location + misspelledRange.length;
    };

    return result;
  }

  /// Returns a unique tag to identified this spell checked object.
  ///
  /// Use this method to generate tags to avoid collisions with other objects that can be spell checked.
  func uniqueSpellDocumentTag() throws -> Int64 {
    return Int64(NSSpellChecker.uniqueSpellDocumentTag());
  }

  /// Notifies the receiver that the user has finished with the tagged document.
  ///
  /// The spell checker will release any resources associated with the document,
  /// including but not necessarily limited to, ignored words.
  func closeSpellDocument(tag: Int64) throws {
    let spellChecker = NSSpellChecker.shared;

    spellChecker.closeSpellDocument(withTag: Int(tag));
  }
  
  /// Starts the search for a misspelled word in [stringToCheck] starting at [startingOffset]
  /// within the string object.
  ///
  /// - [stringToCheck]: The string object containing the words to spellcheck.
  /// - [startingOffset]: The offset within the string object at which to start the spellchecking.
  /// - [language]: The language of the words in the string.
  /// - [wrap]: `true` to indicate that spell checking should continue at the beginning of the string
  ///   when the end of the string is reached; `false` to indicate that spellchecking should stop
  ///   at the end of the document.
  /// - [inSpellDocumentWithTag]: An identifier unique within the application
  ///   used to inform the spell checker which document that text is associated, potentially
  ///   for many purposes, not necessarily just for ignored words. A value of 0 can be passed
  ///   in for text not associated with a particular document.
  ///
  /// Returns the range of the first misspelled word.
  func checkSpelling(stringToCheck: String, startingOffset: Int64, language: String?, wrap: Bool, inSpellDocumentWithTag: Int64) throws -> Range {
    let spellChecker = NSSpellChecker.shared;

    let result = spellChecker.checkSpelling(
      of: stringToCheck, 
      startingAt: Int(startingOffset),
      language: language,
      wrap: wrap,
      inSpellDocumentWithTag: Int(inSpellDocumentWithTag),
      wordCount: nil
    );

    if (result.location == NSNotFound) {
      return Range(start: -1, end: -1);
    }

    return Range(
      start: Int64(result.location),
      end: Int64(result.location + result.length)
    );
  }

  /// Returns an array of possible substitutions for the specified string.
  ///
  /// - [range]: The range of the string to check.
  /// - [text]: The string to guess.
  /// - [language]: The language of the string.
  /// - [inSpellDocumentWithTag]: An identifier unique within the application
  ///   used to inform the spell checker which document that text is associated, potentially
  ///   for many purposes, not necessarily just for ignored words. A value of 0 can be passed
  ///   in for text not associated with a particular document.
  ///
  /// Returns an array of strings containing possible replacement words.
  func guesses(range: Range, text: String, language: String?, inSpellDocumentWithTag: Int64) throws -> [String?]? {
    let spellChecker = NSSpellChecker.shared;

    return spellChecker.guesses(
      forWordRange: NSRange(location: Int(range.start), length: Int(range.end - range.start)),
      in: text,
      language: language,
      inSpellDocumentWithTag: Int(inSpellDocumentWithTag)
    );
  }  

  /// Initiates a grammatical analysis of a given string.
  ///
  /// - [stringToCheck]: The string to analyze.
  /// - [startingOffset]: Location within string at which to start the analysis.
  /// - [language]: Language to use in string.
  /// - [wrap]: `true` to specify that the analysis continue to the beginning of string when
  ///   the end is reached. `false` to have the analysis stop at the end of string.
  /// - [inSpellDocumentWithTag]: An identifier unique within the application
  ///   used to inform the spell checker which document that text is associated, potentially
  ///   for many purposes, not necessarily just for ignored words. A value of 0 can be passed
  ///   in for text not associated with a particular document.
  func checkGrammar(stringToCheck: String, startingOffset: Int64, language: String?, wrap: Bool, inSpellDocumentWithTag: Int64) throws -> PlatformCheckGrammarResult {
    let spellChecker = NSSpellChecker.shared;
    
    var details: NSArray?;
    let grammarRange = spellChecker.checkGrammar(
      of: stringToCheck,
      startingAt: Int(startingOffset),
      language: language,
      wrap: wrap,
      inSpellDocumentWithTag: Int(inSpellDocumentWithTag),
      details: &details
    );
    
    if (grammarRange.location == NSNotFound || details == nil) {
      return PlatformCheckGrammarResult(
        firstError: Range(start: -1, end: -1),
        details: []
      );
    }
    
    let grammarDetails = details as! [[String: Any]];    
    let analysisDetails : [PlatformGrammaticalAnalysisDetail] = grammarDetails.compactMap{ (detail: [String: Any]) -> PlatformGrammaticalAnalysisDetail? in
      let range = detail["NSGrammarRange"] as? NSRange;
      let userDescription = detail["NSGrammarUserDescription"] as? String;
      
      if (range == nil || userDescription == nil) {
          return nil;
          
      }
      
      return PlatformGrammaticalAnalysisDetail(
        range: Range(start: Int64(range!.location), end: Int64(range!.location + range!.length)), 
        userDescription: userDescription!
      );
    };
    
    return PlatformCheckGrammarResult(
      firstError: Range(start: Int64(grammarRange.location), end: Int64(grammarRange.location + grammarRange.length)),
      details: analysisDetails
    );
  }

  /// Returns the number of words in the specified string.
  func countWords(text: String, language: String?) throws -> Int64 {
    let spellChecker = NSSpellChecker.shared;

    return Int64(spellChecker.countWords(in: text, language: language));
  }

  /// Adds the [word] to the spell checker dictionary.
  func learnWord(word: String) throws {
    NSSpellChecker.shared.learnWord(word);
  }

  /// Indicates whether the spell checker has learned a given word.
  func hasLearnedWord(word: String) throws -> Bool {
    return NSSpellChecker.shared.hasLearnedWord(word);
  }

  /// Tells the spell checker to unlearn a given word.
  func unlearnWord(word: String) throws {
    NSSpellChecker.shared.unlearnWord(word);
  }

  /// Instructs the spell checker to ignore all future occurrences of [word] in the document
  /// identified by [documentTag].
  func ignoreWord(word: String, documentTag: Int64) throws {
    NSSpellChecker.shared.ignoreWord(word, inSpellDocumentWithTag: Int(documentTag));
  }

  /// Returns the array of ignored words for a document identified by [documentTag].
  func ignoredWords(documentTag: Int64) throws -> [String]? {
    return NSSpellChecker.shared.ignoredWords(inSpellDocumentWithTag: Int(documentTag));
  }

  /// Initializes the ignored-words document (a dictionary identified by [documentTag] with [words]),
  /// an array of words to ignore.
  func setIgnoredWords(words: [String], documentTag: Int64) throws {
    NSSpellChecker.shared.setIgnoredWords(words, inSpellDocumentWithTag: Int(documentTag));
  }

  /// Returns the dictionary used when replacing words.
  func userReplacementsDictionary() throws -> [String: String] {
    return NSSpellChecker.shared.userReplacementsDictionary;
  }

  /// Provides a list of complete words that the user might be trying to type based on a
  /// partial word in a given string.
  ///
  /// - [partialWordRange] - Range that identifies a partial word in string.
  /// - [text] - String with the partial word from which to generate the result.
  /// - [language]: Language to use in string.
  /// - [inSpellDocumentWithTag]: An identifier unique within the application
  ///   used to inform the spell checker which document that text is associated, potentially
  ///   for many purposes, not necessarily just for ignored words. A value of 0 can be passed
  ///   in for text not associated with a particular document.
  ///
  /// Returns the list of complete words from the spell checker dictionary in the order
  /// they should be presented to the user.
  func completions(partialWordRange: Range, text: String, language: String?, inSpellDocumentWithTag: Int64) throws -> [String]? {
    let spellChecker = NSSpellChecker.shared;

    return spellChecker.completions(      
      forPartialWordRange: NSRange(location: Int(partialWordRange.start), length: Int(partialWordRange.end - partialWordRange.start)),
      in: text,
      language: language,
      inSpellDocumentWithTag: Int(inSpellDocumentWithTag)
    );
  }
}