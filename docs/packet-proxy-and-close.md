# WeakProxy open and receipt-gated close

Baseline is 3.70 / 924dd034e99b479eb3b31a2f94f1807d685dcdb9. The user supplied two new device traces: the native page appears, then UIButton -> WeakProxy -> openButtonClick and another UIButton -> WeakProxy -> dismissView both show encoding-none, followed by unresolved-manual-observation-only. 3.70 is not device-accepted. The new request includes closing the packet page after receipt. Other features and the two retired log sinks remain unchanged.

## Primary evidence in the locked TIM 4.1.0.81 Mach-O

WeakProxy -target: @16@0:8, IMP 0x10013e018. -forwardingTargetForSelector:: @24@0:8:16, IMP 0x1003a6a5c. These two routines load the same weak ivar through the same helper and return it; the forwarding path ignores the selector. The class's -methodSignatureForSelector: at 0x1003a6ae8 produces a generic constant signature, not the true action ABI. Never use it to authorize dispatch. User trace supplies the exact openButtonClick/dismissView bindings; they are not speculative selectors.

The implementation permits one unwrap only for the exact runtime WeakProxy class after checking both accessor/forwarder encodings. It retains the getter result while comparing the forwarding result, rejects nil/self/nested/changed targets, and validates the real declared action's void return, arity and object argument encodings. It still sends the original UIControl TouchUpInside event through the proxy rather than bypassing it. An image-only open is allowed only for the exact observed WeakProxy -> openButtonClick binding plus the existing new-view, unique-binding, visibility, foreground/account/setting and Wallet module checks. Arbitrary forwarding proxies, inferred signatures and fuzzy selector matches are rejected.

## Close confirmation and limitations

The close action must be the exact registered dismissView binding on a unique still-visible native control belonging to the same real receiver that opened this packet. Close candidates are categorically excluded from open candidates. A new route cannot overlap an opened pending packet. User interaction cancels all subsequent automatic steps.

A nil-error callback or an open method returning is not receipt evidence. Auto-close additionally requires the same native OCWalletElement received by this route to transition from grabbedAmount == 0 to grabbedAmount > 0, through its verified Q16@0:8 getter (0x10a28002c). Production never writes the field or invents grabState enums. A native error veto is latched. The observation is a native local received-amount model signal, not independent server settlement proof. Six bounded close checks run over 9.5 seconds; absent/unsupported/unchanged model state, error, changed receiver, ambiguous or covered close control leave the UI available for the user rather than hiding a failure.

The dynamic Wallet UI implementation was not supplied. Whether real TIM updates the same wallet object, keeps the same receiver/control, and actually credits receipt remains device-untested. If it copies the model or navigates to a new controller, auto-close deliberately does not guess navigation/pop/dismiss methods. Optional diagnostics retain only fixed state labels and runtime identifiers, never amount values, accounts, message contents or credentials.

## Regression

The real UIKit fixture now uses actual weak target forwarding, an image-only UIButton with openButtonClick, a distinct dismissView close button, and the real production route/amount getter. It reproduces the original class method lookup returning NULL, requires private/group native open and close once, and rejects a nil weak receiver, an incompatible BOOL action behind a dummy void signature, a nil-error callback with no model receipt, and a native error despite a positive model field. Existing manual-cancel/ambiguity/payment/foreground-token protections remain gates. Fixtures are not real TIM device acceptance.
