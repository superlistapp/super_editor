import 'package:mockito/mockito.dart';
import 'package:super_editor/src/core/document_layout.dart';

/// Fake [DocumentLayout], intended for tests that interact with
/// a logical [DocumentLayout] but do not depend upon a real
/// widget tree with a real [DocumentLayout] implementation.
class FakeDocumentLayout with Mock implements DocumentLayout {}
