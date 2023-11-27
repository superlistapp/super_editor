import 'package:collection/collection.dart';
import 'package:flutter/services.dart';

extension TextInputConfigurationEquivalency on TextInputConfiguration {
  /// Whether this [TextInputConfiguration] is equivalent to [other].
  ///
  /// Two [TextInputConfiguration]s are considered to be equal
  /// if all properties are equal.
  bool isEquivalentTo(TextInputConfiguration other) {
    return inputType == other.inputType &&
        readOnly == other.readOnly &&
        obscureText == other.obscureText &&
        autocorrect == other.autocorrect &&
        autofillConfiguration.isEquivalentTo(other.autofillConfiguration) &&
        smartDashesType == other.smartDashesType &&
        smartQuotesType == other.smartQuotesType &&
        enableSuggestions == other.enableSuggestions &&
        enableInteractiveSelection == other.enableInteractiveSelection &&
        actionLabel == other.actionLabel &&
        inputAction == other.inputAction &&
        textCapitalization == other.textCapitalization &&
        keyboardAppearance == other.keyboardAppearance &&
        enableIMEPersonalizedLearning == other.enableIMEPersonalizedLearning &&
        enableDeltaModel == other.enableDeltaModel &&
        const DeepCollectionEquality().equals(allowedMimeTypes, other.allowedMimeTypes);
  }
}

extension AutofillConfigurationEquivalency on AutofillConfiguration {
  /// Whether this [AutofillConfiguration] is equivalent to [other].
  ///
  /// Two [AutofillConfiguration]s are considered to be equal
  /// if all properties are equal.
  ///
  /// The [currentEditingValue] isn't considered in the comparison.
  /// Otherwise, whenever the user changes the text or selection
  /// would result in two configurations being unequal.
  bool isEquivalentTo(AutofillConfiguration other) {
    return enabled == other.enabled &&
        uniqueIdentifier == other.uniqueIdentifier &&
        const DeepCollectionEquality().equals(autofillHints, other.autofillHints) &&
        hintText == other.hintText;
  }
}
