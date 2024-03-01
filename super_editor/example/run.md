I/ViewRootImpl@389dea8[MainActivity](11453): ViewPostIme pointer 0
I/ViewRootImpl@389dea8[MainActivity](11453): ViewPostIme pointer 1
I/IMM_LC (11453): showSoftInput(View,I)
I/IMM_LC (11453): ssi() - flag : 0 view : com.supereditor.example reason = SHOW_SOFT_INPUT
I/IMM_LC (11453): ssi() view is not EditText
I/flutter (11453): (15.252) editor.ime > FINE: [DocumentImeInputClient] - Serializing and sending document and selection to IME
I/flutter (11453): (15.262) editor.ime > FINE: [DocumentImeInputClient] - Selection: [DocumentSelection] -
I/flutter (11453): base: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.upstream))),
I/flutter (11453): extent: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.upstream)))
I/flutter (11453): (15.263) editor.ime > FINE: [DocumentImeInputClient] - Composing region: null
I/flutter (11453): (15.265) editor.ime > FINE: Creating an IME model from document, selection, and composing region
I/flutter (11453): (15.269) editor.ime > FINE: IME serialization:
I/flutter (11453): '. SuperTextField is a ready-made, configurable text field.'
I/flutter (11453): (15.269) editor.ime > FINE: [DocumentImeInputClient] - Adding invisible characters?: true
I/flutter (11453): (15.270) editor.ime > FINE: Creating TextEditingValue from document. Selection: [DocumentSelection] -
I/flutter (11453): base: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.upstream))),
I/flutter (11453): extent: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.upstream)))
I/flutter (11453): (15.270) editor.ime > FINE: Text:
I/flutter (11453): '. SuperTextField is a ready-made, configurable text field.'
I/flutter (11453): (15.271) editor.ime > FINE: Converting doc selection to ime selection: [DocumentSelection] -
I/flutter (11453): base: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.upstream))),
I/flutter (11453): extent: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.upstream)))
I/flutter (11453): (15.273) editor.ime > FINE: Converting DocumentPosition to IME TextPosition: [DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.upstream))
I/flutter (11453): (15.273) editor.ime > FINE: Converting DocumentPosition to IME TextPosition: [DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.upstream))
I/flutter (11453): (15.274) editor.ime > FINE: Start IME position: TextPosition(offset: 58, affinity: TextAffinity.downstream)
I/flutter (11453): (15.274) editor.ime > FINE: End IME position: TextPosition(offset: 58, affinity: TextAffinity.downstream)
I/flutter (11453): (15.274) editor.ime > FINE: Selection: TextSelection.collapsed(offset: 58, affinity: TextAffinity.downstream, isDirectional: false)
I/flutter (11453): (15.275) editor.ime > FINE: Converting doc range to ime range: null
I/flutter (11453): (15.275) editor.ime > FINE: The document range is null. Returning an empty IME range.
I/flutter (11453): (15.275) editor.ime > FINE: Composing region: TextRange(start: -1, end: -1)
I/flutter (11453): (15.276) editor.ime > FINE: [DocumentImeInputClient] - Sending IME serialization:
I/flutter (11453): (15.277) editor.ime > FINE: [DocumentImeInputClient] - TextEditingValue(text: ┤. SuperTextField is a ready-made, configurable text field.├, selection: TextSelection.collapsed(offset: 58, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: -1, end: -1))
I/flutter (11453): (15.278) editor.ime > FINE: Wants to send a value to IME: TextEditingValue(text: ┤. SuperTextField is a ready-made, configurable text field.├, selection: TextSelection.collapsed(offset: 58, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: -1, end: -1))
I/flutter (11453): (15.279) editor.ime > FINE: The current local IME value: TextEditingValue(text: ┤├, selection: TextSelection.invalid, composing: TextRange(start: -1, end: -1))
I/flutter (11453): (15.279) editor.ime > FINE: The current platform IME value: TextEditingValue(text: ┤├, selection: TextSelection.invalid, composing: TextRange(start: -1, end: -1))
I/flutter (11453): (15.280) editor.ime > FINE: Sending forceful update to IME because our local TextEditingValue didn't change, but the IME may have:
I/flutter (11453): (15.280) editor.ime > FINE: TextEditingValue(text: ┤. SuperTextField is a ready-made, configurable text field.├, selection: TextSelection.collapsed(offset: 58, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: -1, end: -1))
I/flutter (11453): (15.283) editor.ime > FINE: [DocumentImeInputClient] - Done sending document to IME
D/InputMethodManager(11453): startInputInner - Id : 0
I/InputMethodManager(11453): startInputInner - mService.startInputOrWindowGainedFocus
W/IInputConnectionWrapper(11453): requestCursorAnchorInfo on inactive InputConnection
D/InsetsController(11453): show(ime(), fromIme=true)
D/InsetsSourceConsumer(11453): setRequestedVisible: visible=true, type=19, host=com.supereditor.example/com.supereditor.example.MainActivity, from=android.view.InsetsSourceConsumer.show:235 android.view.InsetsController.showDirectly:1489 android.view.InsetsController.controlAnimationUnchecked:1137 android.view.InsetsController.applyAnimation:1456 android.view.InsetsController.applyAnimation:1437 android.view.InsetsController.show:976 android.view.ViewRootImpl$ViewRootHandler.handleMessageImpl:6478 android.view.ViewRootImpl$ViewRootHandler.handleMessage:6403 android.os.Handler.dispatchMessage:106 android.os.Looper.loopOnce:226
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: t = android.view.SurfaceControl$Transaction@b6d2455 fN = 141 android.view.SyncRtSurfaceTransactionApplier.applyTransaction:94 android.view.SyncRtSurfaceTransactionApplier.lambda$scheduleApply$0$SyncRtSurfaceTransactionApplier:71 android.view.SyncRtSurfaceTransactionApplier$$ExternalSyntheticLambda0.onFrameDraw:4
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: merge t to BBQ
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: t = android.view.SurfaceControl$Transaction@3451f5b fN = 142 android.view.SyncRtSurfaceTransactionApplier.applyTransaction:94 android.view.SyncRtSurfaceTransactionApplier.lambda$scheduleApply$0$SyncRtSurfaceTransactionApplier:71 android.view.SyncRtSurfaceTransactionApplier$$ExternalSyntheticLambda0.onFrameDraw:4
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: merge t to BBQ
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: t = android.view.SurfaceControl$Transaction@f5e43f8 fN = 143 android.view.SyncRtSurfaceTransactionApplier.applyTransaction:94 android.view.SyncRtSurfaceTransactionApplier.lambda$scheduleApply$0$SyncRtSurfaceTransactionApplier:71 android.view.SyncRtSurfaceTransactionApplier$$ExternalSyntheticLambda0.onFrameDraw:4
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: merge t to BBQ
D/InsetsController(11453): show(ime(), fromIme=true)
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: t = android.view.SurfaceControl$Transaction@da8b0d1 fN = 144 android.view.SyncRtSurfaceTransactionApplier.applyTransaction:94 android.view.SyncRtSurfaceTransactionApplier.lambda$scheduleApply$0$SyncRtSurfaceTransactionApplier:71 android.view.SyncRtSurfaceTransactionApplier$$ExternalSyntheticLambda0.onFrameDraw:4
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: merge t to BBQ
D/InputConnectionAdaptor(11453): The input method toggled cursor monitoring on
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: t = android.view.SurfaceControl$Transaction@9592736 fN = 145 android.view.SyncRtSurfaceTransactionApplier.applyTransaction:94 android.view.SyncRtSurfaceTransactionApplier.lambda$scheduleApply$0$SyncRtSurfaceTransactionApplier:71 android.view.SyncRtSurfaceTransactionApplier$$ExternalSyntheticLambda0.onFrameDraw:4
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: merge t to BBQ
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: t = android.view.SurfaceControl$Transaction@eac5637 fN = 146 android.view.SyncRtSurfaceTransactionApplier.applyTransaction:94 android.view.SyncRtSurfaceTransactionApplier.lambda$scheduleApply$0$SyncRtSurfaceTransactionApplier:71 android.view.SyncRtSurfaceTransactionApplier$$ExternalSyntheticLambda0.onFrameDraw:4
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: merge t to BBQ
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: t = android.view.SurfaceControl$Transaction@72fa7a4 fN = 147 android.view.SyncRtSurfaceTransactionApplier.applyTransaction:94 android.view.SyncRtSurfaceTransactionApplier.lambda$scheduleApply$0$SyncRtSurfaceTransactionApplier:71 android.view.SyncRtSurfaceTransactionApplier$$ExternalSyntheticLambda0.onFrameDraw:4
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: merge t to BBQ
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: t = android.view.SurfaceControl$Transaction@136890d fN = 148 android.view.SyncRtSurfaceTransactionApplier.applyTransaction:94 android.view.SyncRtSurfaceTransactionApplier.lambda$scheduleApply$0$SyncRtSurfaceTransactionApplier:71 android.view.SyncRtSurfaceTransactionApplier$$ExternalSyntheticLambda0.onFrameDraw:4
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: merge t to BBQ
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: t = android.view.SurfaceControl$Transaction@f0880c2 fN = 149 android.view.SyncRtSurfaceTransactionApplier.applyTransaction:94 android.view.SyncRtSurfaceTransactionApplier.lambda$scheduleApply$0$SyncRtSurfaceTransactionApplier:71 android.view.SyncRtSurfaceTransactionApplier$$ExternalSyntheticLambda0.onFrameDraw:4
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: merge t to BBQ
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: t = android.view.SurfaceControl$Transaction@5e61ed3 fN = 150 android.view.SyncRtSurfaceTransactionApplier.applyTransaction:94 android.view.SyncRtSurfaceTransactionApplier.lambda$scheduleApply$0$SyncRtSurfaceTransactionApplier:71 android.view.SyncRtSurfaceTransactionApplier$$ExternalSyntheticLambda0.onFrameDraw:4
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: merge t to BBQ
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: t = android.view.SurfaceControl$Transaction@a919a10 fN = 151 android.view.SyncRtSurfaceTransactionApplier.applyTransaction:94 android.view.SyncRtSurfaceTransactionApplier.lambda$scheduleApply$0$SyncRtSurfaceTransactionApplier:71 android.view.SyncRtSurfaceTransactionApplier$$ExternalSyntheticLambda0.onFrameDraw:4
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: merge t to BBQ
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: t = android.view.SurfaceControl$Transaction@54fa909 fN = 152 android.view.SyncRtSurfaceTransactionApplier.applyTransaction:94 android.view.SyncRtSurfaceTransactionApplier.lambda$scheduleApply$0$SyncRtSurfaceTransactionApplier:71 android.view.SyncRtSurfaceTransactionApplier$$ExternalSyntheticLambda0.onFrameDraw:4
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: merge t to BBQ
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: t = android.view.SurfaceControl$Transaction@e61e70e fN = 153 android.view.SyncRtSurfaceTransactionApplier.applyTransaction:94 android.view.SyncRtSurfaceTransactionApplier.lambda$scheduleApply$0$SyncRtSurfaceTransactionApplier:71 android.view.SyncRtSurfaceTransactionApplier$$ExternalSyntheticLambda0.onFrameDraw:4
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: merge t to BBQ
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: t = android.view.SurfaceControl$Transaction@6e9d52f fN = 154 android.view.SyncRtSurfaceTransactionApplier.applyTransaction:94 android.view.SyncRtSurfaceTransactionApplier.lambda$scheduleApply$0$SyncRtSurfaceTransactionApplier:71 android.view.SyncRtSurfaceTransactionApplier$$ExternalSyntheticLambda0.onFrameDraw:4
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: merge t to BBQ
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: t = android.view.SurfaceControl$Transaction@1de473c fN = 155 android.view.SyncRtSurfaceTransactionApplier.applyTransaction:94 android.view.SyncRtSurfaceTransactionApplier.lambda$scheduleApply$0$SyncRtSurfaceTransactionApplier:71 android.view.SyncRtSurfaceTransactionApplier$$ExternalSyntheticLambda0.onFrameDraw:4
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: merge t to BBQ
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: t = android.view.SurfaceControl$Transaction@9c0ccc5 fN = 156 android.view.SyncRtSurfaceTransactionApplier.applyTransaction:94 android.view.SyncRtSurfaceTransactionApplier.lambda$scheduleApply$0$SyncRtSurfaceTransactionApplier:71 android.view.SyncRtSurfaceTransactionApplier$$ExternalSyntheticLambda0.onFrameDraw:4
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: merge t to BBQ
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: t = android.view.SurfaceControl$Transaction@ad9661a fN = 157 android.view.SyncRtSurfaceTransactionApplier.applyTransaction:94 android.view.SyncRtSurfaceTransactionApplier.lambda$scheduleApply$0$SyncRtSurfaceTransactionApplier:71 android.view.SyncRtSurfaceTransactionApplier$$ExternalSyntheticLambda0.onFrameDraw:4
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: merge t to BBQ
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: t = android.view.SurfaceControl$Transaction@dc8954b fN = 158 android.view.SyncRtSurfaceTransactionApplier.applyTransaction:94 android.view.SyncRtSurfaceTransactionApplier.lambda$scheduleApply$0$SyncRtSurfaceTransactionApplier:71 android.view.SyncRtSurfaceTransactionApplier$$ExternalSyntheticLambda0.onFrameDraw:4
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: merge t to BBQ
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: t = android.view.SurfaceControl$Transaction@ee69b28 fN = 159 android.view.SyncRtSurfaceTransactionApplier.applyTransaction:94 android.view.SyncRtSurfaceTransactionApplier.lambda$scheduleApply$0$SyncRtSurfaceTransactionApplier:71 android.view.SyncRtSurfaceTransactionApplier$$ExternalSyntheticLambda0.onFrameDraw:4
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: merge t to BBQ
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: t = android.view.SurfaceControl$Transaction@4667041 fN = 160 android.view.SyncRtSurfaceTransactionApplier.applyTransaction:94 android.view.SyncRtSurfaceTransactionApplier.lambda$scheduleApply$0$SyncRtSurfaceTransactionApplier:71 android.view.SyncRtSurfaceTransactionApplier$$ExternalSyntheticLambda0.onFrameDraw:4
I/ViewRootImpl@389dea8[MainActivity](11453): mWNT: merge t to BBQ
I/flutter (11453): (17.088) editor.ime > FINE: Received edit deltas from platform: 3 deltas
I/flutter (11453): (17.091) editor.ime > FINE: TextEditingDeltaNonTextUpdate#8becf(oldText: . SuperTextField is a ready-made, configurable text field., selection: TextSelection.collapsed(offset: 58, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: -1, end: -1))
I/flutter (11453): (17.092) editor.ime > FINE: TextEditingDeltaNonTextUpdate#e3448(oldText: . SuperTextField is a ready-made, configurable text field., selection: TextSelection.collapsed(offset: 58, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: -1, end: -1))
D/InputConnectionAdaptor(11453): The input method toggled text monitoring on
I/flutter (11453): (17.092) editor.ime > FINE: TextEditingDeltaNonTextUpdate#7cebf(oldText: . SuperTextField is a ready-made, configurable text field., selection: TextSelection.collapsed(offset: 58, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: 52, end: 58))
I/flutter (11453): (17.093) editor.ime > FINE: IME value before applying deltas: TextEditingValue(text: ┤. SuperTextField is a ready-made, configurable text field.├, selection: TextSelection.collapsed(offset: 58, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: -1, end: -1))
I/flutter (11453): (17.093) editor.ime > FINE: ===================================================
I/flutter (11453): (17.096) editor.ime > INFO: Applying 3 IME deltas to document
I/flutter (11453): (17.096) editor.ime.deltas > FINE: Incoming deltas:
I/flutter (11453): (17.097) editor.ime.deltas > FINE: TextEditingDeltaNonTextUpdate#8becf(oldText: . SuperTextField is a ready-made, configurable text field., selection: TextSelection.collapsed(offset: 58, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: -1, end: -1))
I/flutter (11453): (17.097) editor.ime.deltas > FINE: TextEditingDeltaNonTextUpdate#e3448(oldText: . SuperTextField is a ready-made, configurable text field., selection: TextSelection.collapsed(offset: 58, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: -1, end: -1))
I/flutter (11453): (17.098) editor.ime.deltas > FINE: TextEditingDeltaNonTextUpdate#7cebf(oldText: . SuperTextField is a ready-made, configurable text field., selection: TextSelection.collapsed(offset: 58, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: 52, end: 58))
I/flutter (11453): (17.098) editor.ime > FINE: Serializing document to perform IME operations
I/flutter (11453): (17.098) editor.ime > FINE: Creating an IME model from document, selection, and composing region
I/flutter (11453): (17.098) editor.ime > FINE: IME serialization:
I/flutter (11453): '. SuperTextField is a ready-made, configurable text field.'
I/flutter (11453): (17.099) editor.ime > FINE: Converting doc selection to ime selection: [DocumentSelection] -
I/flutter (11453): base: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.upstream))),
I/flutter (11453): extent: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.upstream)))
I/flutter (11453): (17.099) editor.ime > FINE: Converting DocumentPosition to IME TextPosition: [DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.upstream))
I/flutter (11453): (17.099) editor.ime > FINE: Converting DocumentPosition to IME TextPosition: [DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.upstream))
I/flutter (11453): (17.099) editor.ime > FINE: Start IME position: TextPosition(offset: 58, affinity: TextAffinity.downstream)
I/flutter (11453): (17.099) editor.ime > FINE: End IME position: TextPosition(offset: 58, affinity: TextAffinity.downstream)
I/flutter (11453): (17.099) editor.ime > FINE: Converting doc range to ime range: null
I/flutter (11453): (17.099) editor.ime > FINE: The document range is null. Returning an empty IME range.
I/flutter (11453): (17.100) editor.ime > INFO: ---------------------------------------------------
I/flutter (11453): (17.100) editor.ime > INFO: Applying delta: TextEditingDeltaNonTextUpdate#8becf(oldText: . SuperTextField is a ready-made, configurable text field., selection: TextSelection.collapsed(offset: 58, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: -1, end: -1))
I/flutter (11453): (17.101) editor.ime > FINE: Non-text change:
I/flutter (11453): (17.102) editor.ime > FINE: OS-side selection - TextSelection.collapsed(offset: 58, affinity: TextAffinity.downstream, isDirectional: false)
I/flutter (11453): (17.102) editor.ime > FINE: OS-side composing - TextRange(start: -1, end: -1)
I/flutter (11453): (17.103) editor.ime > FINE: Creating doc selection from IME selection: TextSelection.collapsed(offset: 58, affinity: TextAffinity.downstream, isDirectional: false)
I/flutter (11453): (17.104) editor.ime > FINE: The IME only selected visible characters. No adjustment necessary.
I/flutter (11453): (17.104) editor.ime > FINE: Calculating the base DocumentPosition for the DocumentSelection
I/flutter (11453): (17.106) editor.ime > FINE: Selection base: [DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.downstream))
I/flutter (11453): (17.107) editor.ime > FINE: Calculating the extent DocumentPosition for the DocumentSelection
I/flutter (11453): (17.107) editor.ime > FINE: Selection extent: [DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.downstream))
I/flutter (11453): (17.109) editor.ime > FINE: Creating doc range from IME range: TextRange(start: -1, end: -1)
I/flutter (11453): (17.109) editor.ime > FINE: The IME range is empty. Returning null document range.
I/IMM_LC (11453): showSoftInput(View,I)
I/IMM_LC (11453): ssi() - flag : 0 view : com.supereditor.example reason = SHOW_SOFT_INPUT
I/IMM_LC (11453): ssi() view is not EditText
I/flutter (11453): (17.114) editor.ime > INFO: ---------------------------------------------------
I/flutter (11453): (17.114) editor.ime > INFO: ---------------------------------------------------
I/flutter (11453): (17.115) editor.ime > INFO: Applying delta: TextEditingDeltaNonTextUpdate#e3448(oldText: . SuperTextField is a ready-made, configurable text field., selection: TextSelection.collapsed(offset: 58, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: -1, end: -1))
I/flutter (11453): (17.115) editor.ime > FINE: Non-text change:
I/flutter (11453): (17.115) editor.ime > FINE: OS-side selection - TextSelection.collapsed(offset: 58, affinity: TextAffinity.downstream, isDirectional: false)
I/flutter (11453): (17.115) editor.ime > FINE: OS-side composing - TextRange(start: -1, end: -1)
I/flutter (11453): (17.116) editor.ime > FINE: Creating doc selection from IME selection: TextSelection.collapsed(offset: 58, affinity: TextAffinity.downstream, isDirectional: false)
I/flutter (11453): (17.116) editor.ime > FINE: The IME only selected visible characters. No adjustment necessary.
I/flutter (11453): (17.116) editor.ime > FINE: Calculating the base DocumentPosition for the DocumentSelection
I/flutter (11453): (17.116) editor.ime > FINE: Selection base: [DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.downstream))
I/flutter (11453): (17.116) editor.ime > FINE: Calculating the extent DocumentPosition for the DocumentSelection
I/flutter (11453): (17.116) editor.ime > FINE: Selection extent: [DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.downstream))
I/flutter (11453): (17.116) editor.ime > FINE: Creating doc range from IME range: TextRange(start: -1, end: -1)
I/flutter (11453): (17.117) editor.ime > FINE: The IME range is empty. Returning null document range.
I/flutter (11453): (17.117) editor.ime > INFO: ---------------------------------------------------
I/flutter (11453): (17.118) editor.ime > INFO: ---------------------------------------------------
I/flutter (11453): (17.118) editor.ime > INFO: Applying delta: TextEditingDeltaNonTextUpdate#7cebf(oldText: . SuperTextField is a ready-made, configurable text field., selection: TextSelection.collapsed(offset: 58, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: 52, end: 58))
I/flutter (11453): (17.118) editor.ime > FINE: Non-text change:
I/flutter (11453): (17.118) editor.ime > FINE: OS-side selection - TextSelection.collapsed(offset: 58, affinity: TextAffinity.downstream, isDirectional: false)
I/flutter (11453): (17.119) editor.ime > FINE: OS-side composing - TextRange(start: 52, end: 58)
I/flutter (11453): (17.119) editor.ime > FINE: Creating doc selection from IME selection: TextSelection.collapsed(offset: 58, affinity: TextAffinity.downstream, isDirectional: false)
I/flutter (11453): (17.119) editor.ime > FINE: The IME only selected visible characters. No adjustment necessary.
I/flutter (11453): (17.119) editor.ime > FINE: Calculating the base DocumentPosition for the DocumentSelection
I/flutter (11453): (17.119) editor.ime > FINE: Selection base: [DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.downstream))
I/flutter (11453): (17.119) editor.ime > FINE: Calculating the extent DocumentPosition for the DocumentSelection
I/flutter (11453): (17.119) editor.ime > FINE: Selection extent: [DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.downstream))
I/flutter (11453): (17.120) editor.ime > FINE: Creating doc range from IME range: TextRange(start: 52, end: 58)
I/flutter (11453): (17.120) editor.ime > FINE: Removing arbitrary character from IME range.
I/flutter (11453): (17.120) editor.ime > FINE: Before adjustment, range: TextRange(start: 52, end: 58)
I/flutter (11453): (17.120) editor.ime > FINE: Prepended characters length: 2
I/flutter (11453): (17.120) editor.ime > FINE: Adjusted IME range to: TextRange(start: 52, end: 58)
I/flutter (11453): (17.127) editor.ime > INFO: ---------------------------------------------------
I/flutter (11453): (17.128) editor.ime > FINE: After applying all deltas, converting the final composing region to a document range.
I/flutter (11453): (17.128) editor.ime > FINE: Raw IME delta composing region: TextRange(start: 52, end: 58)
I/flutter (11453): (17.128) editor.ime > FINE: Creating doc range from IME range: TextRange(start: 52, end: 58)
I/flutter (11453): (17.128) editor.ime > FINE: Removing arbitrary character from IME range.
I/flutter (11453): (17.129) editor.ime > FINE: Before adjustment, range: TextRange(start: 52, end: 58)
I/flutter (11453): (17.129) editor.ime > FINE: Prepended characters length: 2
I/flutter (11453): (17.129) editor.ime > FINE: Adjusted IME range to: TextRange(start: 52, end: 58)
D/InsetsController(11453): show(ime(), fromIme=true)
I/flutter (11453): (17.130) editor.ime > FINE: Document composing region: [DocumentRange] - start: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 50, affinity: TextAffinity.downstream))), end: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.downstream)))
I/flutter (11453): (17.130) editor.ime > FINE: ===================================================
I/flutter (11453): (17.131) editor.ime > FINE: [DocumentImeInputClient] - Serializing and sending document and selection to IME
I/flutter (11453): (17.131) editor.ime > FINE: [DocumentImeInputClient] - Selection: [DocumentSelection] -
I/flutter (11453): base: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.downstream))),
I/flutter (11453): extent: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.downstream)))
I/flutter (11453): (17.131) editor.ime > FINE: [DocumentImeInputClient] - Composing region: [DocumentRange] - start: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 50, affinity: TextAffinity.downstream))), end: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.downstream)))
I/flutter (11453): (17.131) editor.ime > FINE: Creating an IME model from document, selection, and composing region
I/flutter (11453): (17.132) editor.ime > FINE: IME serialization:
I/flutter (11453): '. SuperTextField is a ready-made, configurable text field.'
I/flutter (11453): (17.132) editor.ime > FINE: [DocumentImeInputClient] - Adding invisible characters?: true
I/flutter (11453): (17.132) editor.ime > FINE: Creating TextEditingValue from document. Selection: [DocumentSelection] -
I/flutter (11453): base: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.downstream))),
I/flutter (11453): extent: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.downstream)))
I/flutter (11453): (17.132) editor.ime > FINE: Text:
I/flutter (11453): '. SuperTextField is a ready-made, configurable text field.'
I/flutter (11453): (17.133) editor.ime > FINE: Converting doc selection to ime selection: [DocumentSelection] -
I/flutter (11453): base: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.downstream))),
I/flutter (11453): extent: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.downstream)))
I/flutter (11453): (17.133) editor.ime > FINE: Converting DocumentPosition to IME TextPosition: [DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.downstream))
I/flutter (11453): (17.133) editor.ime > FINE: Converting DocumentPosition to IME TextPosition: [DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.downstream))
I/flutter (11453): (17.133) editor.ime > FINE: Start IME position: TextPosition(offset: 58, affinity: TextAffinity.downstream)
I/flutter (11453): (17.133) editor.ime > FINE: End IME position: TextPosition(offset: 58, affinity: TextAffinity.downstream)
I/flutter (11453): (17.133) editor.ime > FINE: Selection: TextSelection.collapsed(offset: 58, affinity: TextAffinity.downstream, isDirectional: false)
I/flutter (11453): (17.133) editor.ime > FINE: Converting doc range to ime range: [DocumentRange] - start: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 50, affinity: TextAffinity.downstream))), end: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.downstream)))
I/flutter (11453): (17.134) editor.ime > FINE: Converting DocumentPosition to IME TextPosition: [DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 50, affinity: TextAffinity.downstream))
I/flutter (11453): (17.134) editor.ime > FINE: Converting DocumentPosition to IME TextPosition: [DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.downstream))
I/flutter (11453): (17.134) editor.ime > FINE: After converting DocumentRange to TextRange:
I/flutter (11453): (17.134) editor.ime > FINE: Start IME position: TextPosition(offset: 52, affinity: TextAffinity.downstream)
I/flutter (11453): (17.134) editor.ime > FINE: End IME position: TextPosition(offset: 58, affinity: TextAffinity.downstream)
I/flutter (11453): (17.134) editor.ime > FINE: Composing region: TextRange(start: 52, end: 58)
I/flutter (11453): (17.134) editor.ime > FINE: [DocumentImeInputClient] - Sending IME serialization:
I/flutter (11453): (17.135) editor.ime > FINE: [DocumentImeInputClient] - TextEditingValue(text: ┤. SuperTextField is a ready-made, configurable text field.├, selection: TextSelection.collapsed(offset: 58, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: 52, end: 58))
I/flutter (11453): (17.135) editor.ime > FINE: Wants to send a value to IME: TextEditingValue(text: ┤. SuperTextField is a ready-made, configurable text field.├, selection: TextSelection.collapsed(offset: 58, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: 52, end: 58))
I/flutter (11453): (17.135) editor.ime > FINE: The current local IME value: TextEditingValue(text: ┤. SuperTextField is a ready-made, configurable text field.├, selection: TextSelection.collapsed(offset: 58, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: -1, end: -1))
I/flutter (11453): (17.135) editor.ime > FINE: The current platform IME value: TextEditingValue(text: ┤. SuperTextField is a ready-made, configurable text field.├, selection: TextSelection.collapsed(offset: 58, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: -1, end: -1))
I/flutter (11453): (17.136) editor.ime > FINE: Ignoring new TextEditingValue because it's the same as the existing one: TextEditingValue(text: ┤. SuperTextField is a ready-made, configurable text field.├, selection: TextSelection.collapsed(offset: 58, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: 52, end: 58))
I/flutter (11453): (17.136) editor.ime > FINE: [DocumentImeInputClient] - Done sending document to IME
I/flutter (11453): (17.139) editor.ime > FINE: Received edit deltas from platform: 1 deltas
I/flutter (11453): (17.140) editor.ime > FINE: TextEditingDeltaInsertion#30c85(oldText: . SuperTextField is a ready-made, configurable text field., textInserted: k, insertionOffset: 58, selection: TextSelection.collapsed(offset: 59, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: 52, end: 59))
I/flutter (11453): (17.141) editor.ime > FINE: IME value before applying deltas: TextEditingValue(text: ┤. SuperTextField is a ready-made, configurable text field.├, selection: TextSelection.collapsed(offset: 58, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: 52, end: 58))
I/flutter (11453): (17.141) editor.ime > FINE: ===================================================
I/flutter (11453): (17.143) editor.ime > INFO: Applying 1 IME deltas to document
I/flutter (11453): (17.143) editor.ime.deltas > FINE: Incoming deltas:
I/flutter (11453): (17.143) editor.ime.deltas > FINE: TextEditingDeltaInsertion#30c85(oldText: . SuperTextField is a ready-made, configurable text field., textInserted: k, insertionOffset: 58, selection: TextSelection.collapsed(offset: 59, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: 52, end: 59))
I/flutter (11453): (17.144) editor.ime > FINE: Serializing document to perform IME operations
I/flutter (11453): (17.144) editor.ime > FINE: Creating an IME model from document, selection, and composing region
I/flutter (11453): (17.145) editor.ime > FINE: IME serialization:
I/flutter (11453): '. SuperTextField is a ready-made, configurable text field.'
I/flutter (11453): (17.145) editor.ime > FINE: Converting doc selection to ime selection: [DocumentSelection] -
I/flutter (11453): base: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.downstream))),
I/flutter (11453): extent: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.downstream)))
I/flutter (11453): (17.145) editor.ime > FINE: Converting DocumentPosition to IME TextPosition: [DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.downstream))
I/flutter (11453): (17.146) editor.ime > FINE: Converting DocumentPosition to IME TextPosition: [DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.downstream))
I/flutter (11453): (17.146) editor.ime > FINE: Start IME position: TextPosition(offset: 58, affinity: TextAffinity.downstream)
I/flutter (11453): (17.146) editor.ime > FINE: End IME position: TextPosition(offset: 58, affinity: TextAffinity.downstream)
I/flutter (11453): (17.146) editor.ime > FINE: Converting doc range to ime range: [DocumentRange] - start: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 50, affinity: TextAffinity.downstream))), end: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.downstream)))
I/flutter (11453): (17.147) editor.ime > FINE: Converting DocumentPosition to IME TextPosition: [DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 50, affinity: TextAffinity.downstream))
I/flutter (11453): (17.147) editor.ime > FINE: Converting DocumentPosition to IME TextPosition: [DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.downstream))
I/flutter (11453): (17.147) editor.ime > FINE: After converting DocumentRange to TextRange:
I/flutter (11453): (17.147) editor.ime > FINE: Start IME position: TextPosition(offset: 52, affinity: TextAffinity.downstream)
I/flutter (11453): (17.147) editor.ime > FINE: End IME position: TextPosition(offset: 58, affinity: TextAffinity.downstream)
I/flutter (11453): (17.147) editor.ime > INFO: ---------------------------------------------------
I/flutter (11453): (17.148) editor.ime > INFO: Applying delta: TextEditingDeltaInsertion#30c85(oldText: . SuperTextField is a ready-made, configurable text field., textInserted: k, insertionOffset: 58, selection: TextSelection.collapsed(offset: 59, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: 52, end: 59))
I/flutter (11453): (17.150) editor.ime > FINE: Inserted text: "k"
I/flutter (11453): (17.150) editor.ime > FINE: Insertion offset: 58
I/flutter (11453): (17.150) editor.ime > FINE: Selection: TextSelection.collapsed(offset: 59, affinity: TextAffinity.downstream, isDirectional: false)
I/flutter (11453): (17.151) editor.ime > FINE: Composing: TextRange(start: 52, end: 59)
I/flutter (11453): (17.151) editor.ime > FINE: Old text: ". SuperTextField is a ready-made, configurable text field."
I/flutter (11453): (17.151) editor.ime > FINE: Inserting text: 'k', at insertion offset: 58, with ime selection: TextSelection.collapsed(offset: 59, affinity: TextAffinity.downstream, isDirectional: false)
I/flutter (11453): (17.152) editor.ime > FINE: Converting IME insertion offset into a DocumentSelection
I/flutter (11453): (17.152) editor.ime > FINE: Creating doc selection from IME selection: TextSelection.collapsed(offset: 58, affinity: TextAffinity.downstream, isDirectional: false)
I/flutter (11453): (17.153) editor.ime > FINE: The IME only selected visible characters. No adjustment necessary.
I/flutter (11453): (17.153) editor.ime > FINE: Calculating the base DocumentPosition for the DocumentSelection
I/flutter (11453): (17.153) editor.ime > FINE: Selection base: [DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.downstream))
I/flutter (11453): (17.153) editor.ime > FINE: Calculating the extent DocumentPosition for the DocumentSelection
I/flutter (11453): (17.154) editor.ime > FINE: Selection extent: [DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.downstream))
I/flutter (11453): (17.154) editor.ime > FINE: Inserting "k" at position "[DocumentSelection] -
I/flutter (11453): base: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.downstream))),
I/flutter (11453): extent: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.downstream)))"
I/flutter (11453): (17.155) editor.ime > FINE: Updating the Document Composer's selection to place caret at insertion offset:
I/flutter (11453): [DocumentSelection] -
I/flutter (11453): base: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.downstream))),
I/flutter (11453): extent: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 56, affinity: TextAffinity.downstream)))
I/flutter (11453): (17.155) editor.ime > FINE: Inserting the text at the Document Composer's selection
I/IMM_LC (11453): showSoftInput(View,I)
I/IMM_LC (11453): ssi() - flag : 0 view : com.supereditor.example reason = SHOW_SOFT_INPUT
I/IMM_LC (11453): ssi() view is not EditText
I/flutter (11453): (17.172) editor.ime > FINE: Insertion successful? true
I/flutter (11453): (17.173) editor.ime > FINE: Creating an IME model from document, selection, and composing region
I/flutter (11453): (17.173) editor.ime > FINE: IME serialization:
I/flutter (11453): '. SuperTextField is a ready-made, configurable text field.k'
I/flutter (11453): (17.173) editor.ime > FINE: Creating doc range from IME range: TextRange(start: 52, end: 59)
I/flutter (11453): (17.173) editor.ime > FINE: Removing arbitrary character from IME range.
I/flutter (11453): (17.174) editor.ime > FINE: Before adjustment, range: TextRange(start: 52, end: 59)
I/flutter (11453): (17.174) editor.ime > FINE: Prepended characters length: 2
I/flutter (11453): (17.174) editor.ime > FINE: Adjusted IME range to: TextRange(start: 52, end: 59)
I/flutter (11453): (17.176) editor.ime > INFO: ---------------------------------------------------
I/flutter (11453): (17.176) editor.ime > FINE: After applying all deltas, converting the final composing region to a document range.
I/flutter (11453): (17.176) editor.ime > FINE: Raw IME delta composing region: TextRange(start: 52, end: 59)
I/flutter (11453): (17.177) editor.ime > FINE: Creating doc range from IME range: TextRange(start: 52, end: 59)
I/flutter (11453): (17.177) editor.ime > FINE: Removing arbitrary character from IME range.
I/flutter (11453): (17.177) editor.ime > FINE: Before adjustment, range: TextRange(start: 52, end: 59)
D/InsetsController(11453): show(ime(), fromIme=true)
I/flutter (11453): (17.177) editor.ime > FINE: Prepended characters length: 2
I/flutter (11453): (17.177) editor.ime > FINE: Adjusted IME range to: TextRange(start: 52, end: 59)
I/flutter (11453): (17.178) editor.ime > FINE: Document composing region: [DocumentRange] - start: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 50, affinity: TextAffinity.downstream))), end: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 57, affinity: TextAffinity.downstream)))
I/flutter (11453): (17.178) editor.ime > FINE: ===================================================
I/flutter (11453): (17.178) editor.ime > FINE: [DocumentImeInputClient] - Serializing and sending document and selection to IME
I/flutter (11453): (17.178) editor.ime > FINE: [DocumentImeInputClient] - Selection: [DocumentSelection] -
I/flutter (11453): base: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 57, affinity: TextAffinity.downstream))),
I/flutter (11453): extent: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 57, affinity: TextAffinity.downstream)))
I/flutter (11453): (17.178) editor.ime > FINE: [DocumentImeInputClient] - Composing region: [DocumentRange] - start: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 50, affinity: TextAffinity.downstream))), end: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 57, affinity: TextAffinity.downstream)))
I/flutter (11453): (17.178) editor.ime > FINE: Creating an IME model from document, selection, and composing region
I/flutter (11453): (17.179) editor.ime > FINE: IME serialization:
I/flutter (11453): '. SuperTextField is a ready-made, configurable text field.k'
I/flutter (11453): (17.179) editor.ime > FINE: [DocumentImeInputClient] - Adding invisible characters?: true
I/flutter (11453): (17.179) editor.ime > FINE: Creating TextEditingValue from document. Selection: [DocumentSelection] -
I/flutter (11453): base: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 57, affinity: TextAffinity.downstream))),
I/flutter (11453): extent: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 57, affinity: TextAffinity.downstream)))
I/flutter (11453): (17.179) editor.ime > FINE: Text:
I/flutter (11453): '. SuperTextField is a ready-made, configurable text field.k'
I/flutter (11453): (17.179) editor.ime > FINE: Converting doc selection to ime selection: [DocumentSelection] -
I/flutter (11453): base: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 57, affinity: TextAffinity.downstream))),
I/flutter (11453): extent: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 57, affinity: TextAffinity.downstream)))
I/flutter (11453): (17.179) editor.ime > FINE: Converting DocumentPosition to IME TextPosition: [DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 57, affinity: TextAffinity.downstream))
I/flutter (11453): (17.179) editor.ime > FINE: Converting DocumentPosition to IME TextPosition: [DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 57, affinity: TextAffinity.downstream))
I/flutter (11453): (17.179) editor.ime > FINE: Start IME position: TextPosition(offset: 59, affinity: TextAffinity.downstream)
I/flutter (11453): (17.180) editor.ime > FINE: End IME position: TextPosition(offset: 59, affinity: TextAffinity.downstream)
I/flutter (11453): (17.180) editor.ime > FINE: Selection: TextSelection.collapsed(offset: 59, affinity: TextAffinity.downstream, isDirectional: false)
I/flutter (11453): (17.180) editor.ime > FINE: Converting doc range to ime range: [DocumentRange] - start: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 50, affinity: TextAffinity.downstream))), end: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 57, affinity: TextAffinity.downstream)))
I/flutter (11453): (17.180) editor.ime > FINE: Converting DocumentPosition to IME TextPosition: [DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 50, affinity: TextAffinity.downstream))
I/flutter (11453): (17.180) editor.ime > FINE: Converting DocumentPosition to IME TextPosition: [DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 57, affinity: TextAffinity.downstream))
I/flutter (11453): (17.180) editor.ime > FINE: After converting DocumentRange to TextRange:
I/flutter (11453): (17.180) editor.ime > FINE: Start IME position: TextPosition(offset: 52, affinity: TextAffinity.downstream)
I/flutter (11453): (17.180) editor.ime > FINE: End IME position: TextPosition(offset: 59, affinity: TextAffinity.downstream)
I/flutter (11453): (17.180) editor.ime > FINE: Composing region: TextRange(start: 52, end: 59)
I/flutter (11453): (17.180) editor.ime > FINE: [DocumentImeInputClient] - Sending IME serialization:
I/flutter (11453): (17.181) editor.ime > FINE: [DocumentImeInputClient] - TextEditingValue(text: ┤. SuperTextField is a ready-made, configurable text field.k├, selection: TextSelection.collapsed(offset: 59, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: 52, end: 59))
I/flutter (11453): (17.181) editor.ime > FINE: Wants to send a value to IME: TextEditingValue(text: ┤. SuperTextField is a ready-made, configurable text field.k├, selection: TextSelection.collapsed(offset: 59, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: 52, end: 59))
I/flutter (11453): (17.181) editor.ime > FINE: The current local IME value: TextEditingValue(text: ┤. SuperTextField is a ready-made, configurable text field.├, selection: TextSelection.collapsed(offset: 58, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: 52, end: 58))
I/flutter (11453): (17.181) editor.ime > FINE: The current platform IME value: TextEditingValue(text: ┤. SuperTextField is a ready-made, configurable text field.├, selection: TextSelection.collapsed(offset: 58, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: 52, end: 58))
I/flutter (11453): (17.181) editor.ime > FINE: Ignoring new TextEditingValue because it's the same as the existing one: TextEditingValue(text: ┤. SuperTextField is a ready-made, configurable text field.k├, selection: TextSelection.collapsed(offset: 59, affinity: TextAffinity.downstream, isDirectional: false), composing: TextRange(start: 52, end: 59))
I/flutter (11453): (17.181) editor.ime > FINE: [DocumentImeInputClient] - Done sending document to IME
D/InputConnectionAdaptor(11453): The input method toggled text monitoring off
I/flutter (11453): (19.201) editor.ime > FINE: [DocumentImeInputClient] - Serializing and sending document and selection to IME
I/flutter (11453): (19.201) editor.ime > FINE: [DocumentImeInputClient] - Selection: [DocumentSelection] -
I/flutter (11453): base: ([DocumentPosition] - node: "0c01adfe-c264-4acc-9820-ec65a7bc2601", position: (TextPosition(offset: 0, affinity: TextAffinity.downstream))),
I/flutter (11453): extent: ([DocumentPosition] - node: "0c01adfe-c264-4acc-9820-ec65a7bc2601", position: (TextPosition(offset: 0, affinity: TextAffinity.downstream)))
I/flutter (11453): (19.201) editor.ime > FINE: [DocumentImeInputClient] - Composing region: [DocumentRange] - start: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 50, affinity: TextAffinity.downstream))), end: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 57, affinity: TextAffinity.downstream)))
I/flutter (11453): (19.202) editor.ime > FINE: Creating an IME model from document, selection, and composing region
I/flutter (11453): (19.202) editor.ime > FINE: IME serialization:
I/flutter (11453): '. '
I/flutter (11453): (19.202) editor.ime > FINE: [DocumentImeInputClient] - Adding invisible characters?: true
I/flutter (11453): (19.202) editor.ime > FINE: Creating TextEditingValue from document. Selection: [DocumentSelection] -
I/flutter (11453): base: ([DocumentPosition] - node: "0c01adfe-c264-4acc-9820-ec65a7bc2601", position: (TextPosition(offset: 0, affinity: TextAffinity.downstream))),
I/flutter (11453): extent: ([DocumentPosition] - node: "0c01adfe-c264-4acc-9820-ec65a7bc2601", position: (TextPosition(offset: 0, affinity: TextAffinity.downstream)))
I/flutter (11453): (19.202) editor.ime > FINE: Text:
I/flutter (11453): '. '
I/flutter (11453): (19.202) editor.ime > FINE: Converting doc selection to ime selection: [DocumentSelection] -
I/flutter (11453): base: ([DocumentPosition] - node: "0c01adfe-c264-4acc-9820-ec65a7bc2601", position: (TextPosition(offset: 0, affinity: TextAffinity.downstream))),
I/flutter (11453): extent: ([DocumentPosition] - node: "0c01adfe-c264-4acc-9820-ec65a7bc2601", position: (TextPosition(offset: 0, affinity: TextAffinity.downstream)))
I/flutter (11453): (19.203) editor.ime > FINE: Converting DocumentPosition to IME TextPosition: [DocumentPosition] - node: "0c01adfe-c264-4acc-9820-ec65a7bc2601", position: (TextPosition(offset: 0, affinity: TextAffinity.downstream))
I/flutter (11453): (19.203) editor.ime > FINE: Converting DocumentPosition to IME TextPosition: [DocumentPosition] - node: "0c01adfe-c264-4acc-9820-ec65a7bc2601", position: (TextPosition(offset: 0, affinity: TextAffinity.downstream))
I/flutter (11453): (19.203) editor.ime > FINE: Start IME position: TextPosition(offset: 2, affinity: TextAffinity.downstream)
I/flutter (11453): (19.203) editor.ime > FINE: End IME position: TextPosition(offset: 2, affinity: TextAffinity.downstream)
I/flutter (11453): (19.203) editor.ime > FINE: Selection: TextSelection.collapsed(offset: 2, affinity: TextAffinity.downstream, isDirectional: false)
I/flutter (11453): (19.203) editor.ime > FINE: Converting doc range to ime range: [DocumentRange] - start: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 50, affinity: TextAffinity.downstream))), end: ([DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 57, affinity: TextAffinity.downstream)))
I/flutter (11453): (19.204) editor.ime > FINE: Converting DocumentPosition to IME TextPosition: [DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 50, affinity: TextAffinity.downstream))

════════ Exception caught by foundation library ════════════════════════════════
The following \_Exception was thrown while dispatching notifications for PausableValueNotifier<DocumentSelection?>:
Exception: No such document position in the IME content: [DocumentPosition] - node: "7d667a6e-5036-4667-a274-40dfaae31bad", position: (TextPosition(offset: 50, affinity: TextAffinity.downstream))

When the exception was thrown, this was the stack:
#0 DocumentImeSerializer.\_documentToImePosition (package:super_editor/src/default_editor/document_ime/document_serialization.dart:315:7)
#1 DocumentImeSerializer.documentToImeRange (package:super_editor/src/default_editor/document_ime/document_serialization.dart:299:30)
#2 DocumentImeSerializer.toTextEditingValue (package:super_editor/src/default_editor/document_ime/document_serialization.dart:346:32)
#3 DocumentImeInputClient.\_sendDocumentToIme (package:super_editor/src/default_editor/document_ime/document_ime_communication.dart:260:58)
#4 DocumentImeInputClient.\_onContentChange (package:super_editor/src/default_editor/document_ime/document_ime_communication.dart:83:5)
#5 ChangeNotifier.notifyListeners (package:flutter/src/foundation/change_notifier.dart:433:24)
#6 ValueNotifier.value= (package:flutter/src/foundation/change_notifier.dart:555:5)
#7 PausableValueNotifier.resumeNotifications (package:super_editor/src/infrastructure/pausable_value_notifier.dart:49:11)
#8 MutableDocumentComposer.onTransactionEnd (package:super_editor/src/core/document_composer.dart:156:24)
#9 Editor.execute (package:super_editor/src/core/editor.dart:168:20)
#10 CommonEditorOperations.insertBlockLevelNewline (package:super_editor/src/default_editor/common_editor_operations.dart:1699:14)
#11 enterToInsertBlockNewline (package:super_editor/src/default_editor/paragraph.dart:847:55)
#12 \_SuperEditorHardwareKeyHandlerState.\_onKeyPressed (package:super_editor/src/default_editor/document_hardware_keyboard/document_physical_keyboard.dart:84:50)
#13 \_HighlightModeManager.handleKeyMessage (package:flutter/src/widgets/focus_manager.dart:2002:39)
#14 KeyEventManager.\_dispatchKeyMessage (package:flutter/src/services/hardware_keyboard.dart:1103:34)
#15 KeyEventManager.handleRawKeyMessage (package:flutter/src/services/hardware_keyboard.dart:1175:17)
#16 BasicMessageChannel.setMessageHandler.<anonymous closure> (package:flutter/src/services/platform_channel.dart:235:49)
#17 \_DefaultBinaryMessenger.setMessageHandler.<anonymous closure> (package:flutter/src/services/binding.dart:603:35)
#18 \_invoke2 (dart:ui/hooks.dart:344:13)
#19 \_ChannelCallbackRecord.invoke (dart:ui/channel_buffers.dart:45:5)
#20 \_Channel.push (dart:ui/channel_buffers.dart:135:31)
#21 ChannelBuffers.push (dart:ui/channel_buffers.dart:343:17)
#22 PlatformDispatcher.\_dispatchPlatformMessage (dart:ui/platform_dispatcher.dart:737:22)
#23 \_dispatchPlatformMessage (dart:ui/hooks.dart:257:31)

The PausableValueNotifier<DocumentSelection?> sending notification was: PausableValueNotifier<DocumentSelection?>#6a829([DocumentSelection] -
base: ([DocumentPosition] - node: "0c01adfe-c264-4acc-9820-ec65a7bc2601", position: (TextPosition(offset: 0, affinity: TextAffinity.downstream))),
extent: ([DocumentPosition] - node: "0c01adfe-c264-4acc-9820-ec65a7bc2601", position: (TextPosition(offset: 0, affinity: TextAffinity.downstream))))
════════════════════════════════════════════════════════════════════════════════
I/IMM_LC (11453): showSoftInput(View,I)
I/IMM_LC (11453): ssi() - flag : 0 view : com.supereditor.example reason = SHOW_SOFT_INPUT
I/IMM_LC (11453): ssi() view is not EditText
D/InsetsController(11453): show(ime(), fromIme=true)
