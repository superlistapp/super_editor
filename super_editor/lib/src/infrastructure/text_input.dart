import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The mode of user text input.
enum TextInputSource {
  keyboard,
  ime,
}

/// Whether or not we are running on web.
///
/// By default this is the same as [kIsWeb].
///
/// [debugIsWebOverride] may be used to override the natural value of [isWeb].
bool get isWeb => debugIsWebOverride == null //
    ? kIsWeb
    : debugIsWebOverride == WebPlatformOverride.web;

/// Overrides the value of [isWeb].
///
/// This is intended to be used in tests.
///
/// Set it to `null` to use the default value of [isWeb].
///
/// Set it to [WebPlatformOverride.web] to configure to run as if we are on web.
///
/// Set it to [WebPlatformOverride.native] to configure to run as if we are NOT on web.
@visibleForTesting
WebPlatformOverride? debugIsWebOverride;

@visibleForTesting
enum WebPlatformOverride {
  /// Configuration to run the app as if we are a native app.
  native,

  /// Configuration to run the app as if we are on web.
  web,
}

extension TextInputConfigurationExtensions on TextInputConfiguration {
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

extension AutofillConfigurationExtensions on AutofillConfiguration {
  /// Whether this [AutofillConfiguration] is equivalent to [other].
  ///
  /// Two [AutofillConfiguration]s are considered to be equal
  /// if all properties are equal.
  bool isEquivalentTo(AutofillConfiguration other) {
    return enabled == other.enabled &&
        uniqueIdentifier == other.uniqueIdentifier &&
        const DeepCollectionEquality().equals(autofillHints, other.autofillHints) &&
        currentEditingValue == other.currentEditingValue &&
        hintText == other.hintText;
  }
}
