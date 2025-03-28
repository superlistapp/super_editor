import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A widget that builds and paints nothing.
class BuildNothingBox extends LeafRenderObjectWidget {
  const BuildNothingBox();

  @override
  RenderBuildNothingBox createRenderObject(BuildContext context) {
    return RenderBuildNothingBox();
  }
}

class RenderBuildNothingBox extends RenderProxyBox {}
