export 'document_delta_editing.dart';
export 'document_ime_communication.dart';
export 'document_ime_interaction_policies.dart';
export 'document_serialization.dart';
export 'ime_decoration.dart';
export 'ime_keyboard_control.dart';
export 'mobile_toolbar.dart';
export 'supereditor_ime_interactor.dart';

/// This file exports various document IME tools.
///
/// The term Input Method Engine (IME) refers to an operating system's
/// intermediary between the user's input, such as through a software
/// keyboard, and the app that receives the input. The IME might make
/// changes to the user's input, such as correcting spelling, or
/// inserting emojis.
///
/// IME input is the only form of input available on mobile devices,
/// unless the user connects a physical keyboard. For example, the
/// software keyboard that appears on the screen of a mobile device
/// talks to the OS, not the app. Once the OS receives input from
/// the user through the software keyboard, the OS forwards a version
/// of that input to the appropriate app.
///
/// The tools in this package are all about enabling various behaviors
/// and policies for receiving and applying IME input.
