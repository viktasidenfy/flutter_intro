library flutter_intro;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

part 'delay_rendered_widget.dart';
part 'flutter_intro_exception.dart';
part 'intro_button.dart';
part 'intro_status.dart';
part 'intro_step_builder.dart';
part 'overlay_position.dart';
part 'step_widget_builder.dart';
part 'step_widget_params.dart';
part 'throttling.dart';

class Intro extends InheritedWidget {
  static BuildContext? _context;
  static OverlayEntry? _overlayEntry;
  static bool _removed = false;
  static Size _screenSize = Size(0, 0);
  static Widget _overlayWidget = SizedBox.shrink();
  bool didRelocate = false;
  static int lastStepInteger = 0;
  static IntroStepBuilder? _currentIntroStepBuilder;
  static Size _widgetSize = Size(0, 0);
  static Offset _widgetOffset = Offset(0, 0);

  final _th = _Throttling(duration: Duration(milliseconds: 500));
  final List<IntroStepBuilder> _introStepBuilderList = [];
  final List<IntroStepBuilder> _finishedIntroStepBuilderList = [];
  late final Duration _animationDuration;

  /// [Widget] [padding] of the selected area, the default is [EdgeInsets.all(8)]
  final EdgeInsets padding;

  /// [Widget] [borderRadius] of the selected area, the default is [BorderRadius.all(Radius.circular(4))]
  final BorderRadiusGeometry borderRadius;

  /// The initial mask color of step page
  final Color initialMaskColor;

  /// The mask color of step page
  Color maskColor = Colors.transparent;
  
  /// Is overlay visble
  bool isVisible = true;

  /// No animation
  final bool noAnimation;

  /// Click on whether the mask is allowed to be closed.
  final bool maskClosable;

  /// [order] order
  final String Function(
    int order,
  )? buttonTextBuilder;

  Intro({
    this.padding = const EdgeInsets.all(8),
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
    this.initialMaskColor = const Color.fromRGBO(0, 0, 0, .6),
    this.noAnimation = false,
    this.maskClosable = false,
    this.buttonTextBuilder,
    required Widget child,
  }) : super(child: child) {
    this.maskColor = this.initialMaskColor;
    _animationDuration =
        noAnimation ? Duration(milliseconds: 0) : Duration(milliseconds: 300);
  }

  IntroStatus get status => IntroStatus(isOpen: _overlayEntry != null);

  bool get hasNextStep =>
      _currentIntroStepBuilder == null || lastStepInteger == 10 ||
      _introStepBuilderList.where(
            (element) {
              return element.order > _currentIntroStepBuilder!.order;
            },
          ).length >
          0;

  bool get hasPrevStep =>
      _finishedIntroStepBuilderList
          .indexWhere((element) => element == _currentIntroStepBuilder) >
      0;

  IntroStepBuilder? _getNextIntroStepBuilder({
    bool isUpdate = false,
    bool shouldCount = true
  }) {
    if (isUpdate) {
      return _currentIntroStepBuilder;
    }
    if (shouldCount) {
      Intro.lastStepInteger += 1;
    }
    var current = Intro.lastStepInteger;
    if (_introStepBuilderList.cast<IntroStepBuilder?>().any((element) => element?.order == current)) {
      var introStepBuilder = _introStepBuilderList.cast<IntroStepBuilder?>()
          .firstWhere((element) => element?.order == current);
      return introStepBuilder;
    } else if (_introStepBuilderList.cast<IntroStepBuilder?>().any((element) => element?.order == current + 1)) {
      Intro.lastStepInteger += 1;
      current = Intro.lastStepInteger;
      var introStepBuilder = _introStepBuilderList.cast<IntroStepBuilder?>()
          .firstWhere((element) => element?.order == current);
      return introStepBuilder;
    } else {
      return _currentIntroStepBuilder;
    }
  }

  IntroStepBuilder? _getPrevIntroStepBuilder({
    bool isUpdate = false,
  }) {
    if (isUpdate) {
      return _currentIntroStepBuilder;
    }
    int index = _finishedIntroStepBuilderList
        .indexWhere((element) => element == _currentIntroStepBuilder);
    if (index > 0) {
      return _finishedIntroStepBuilderList[index - 1];
    }
    return null;
  }

  Widget _widgetBuilder({
    double? width,
    double? height,
    BlendMode? backgroundBlendMode,
    required double left,
    required double top,
    double? bottom,
    double? right,
    BorderRadiusGeometry? borderRadiusGeometry,
    Widget? child,
    VoidCallback? onTap,
  }) {
    final decoration = BoxDecoration(
      color: Colors.white,
      backgroundBlendMode: backgroundBlendMode,
      borderRadius: borderRadiusGeometry,
    );
    return AnimatedPositioned(
      duration: _animationDuration,
      child: InkWell(
        onTap: onTap,
        onHover: (hover) {},
        child: AnimatedContainer(
          padding: padding,
          decoration: decoration,
          width: width,
          height: height,
          child: child,
          duration: _animationDuration,
        ),
      ),
      left: left,
      top: top,
      bottom: bottom,
      right: right,
    );
  }

  void _onFinish() {
    if (_overlayEntry == null) return;

    _removed = true;
    _overlayEntry!.markNeedsBuild();
    Timer(_animationDuration, () {
      if (_overlayEntry == null) return;
      _overlayEntry!.remove();
      _removed = false;
      _overlayEntry = null;
      _introStepBuilderList.clear();
      _finishedIntroStepBuilderList.clear();
      _currentIntroStepBuilder = null;
      lastStepInteger = 0;
      didRelocate = false;
    });
  }
  
  void hideOverlay({bool didRelocate = false}) {
    this.didRelocate = didRelocate;
    _overlayWidget = SizedBox.shrink();
    isVisible = false;
  }

  void render({
    bool isUpdate = false,
    bool reverse = false,
    bool shouldCount = true
  }) {
    maskColor = initialMaskColor;
    isVisible = true;
    IntroStepBuilder? introStepBuilder = reverse
        ? _getPrevIntroStepBuilder(
            isUpdate: isUpdate,
          )
        : _getNextIntroStepBuilder(
            isUpdate: isUpdate, shouldCount: shouldCount
          );
    _currentIntroStepBuilder = introStepBuilder;
    if (introStepBuilder == null) {
      _onFinish();
      return;
    }

    BuildContext? currentContext = introStepBuilder._key.currentContext;

    if (currentContext == null) {
      _onFinish();
      print("Intro context is null");
      return;
    }

    RenderBox renderBox = currentContext.findRenderObject() as RenderBox;

    _screenSize = MediaQuery.of(_context!).size;
    _widgetSize = Size(
      renderBox.size.width +
          (introStepBuilder.padding?.horizontal ?? padding.horizontal),
      renderBox.size.height +
          (introStepBuilder.padding?.vertical ?? padding.vertical),
    );
    _widgetOffset = Offset(
      renderBox.localToGlobal(Offset.zero).dx -
          (introStepBuilder.padding?.left ?? padding.left),
      renderBox.localToGlobal(Offset.zero).dy -
          (introStepBuilder.padding?.top ?? padding.top),
    );

    OverlayPosition position = _StepWidgetBuilder.getOverlayPosition(
      screenSize: _screenSize,
      size: _widgetSize,
      offset: _widgetOffset,
    );

    if (!_finishedIntroStepBuilderList.contains(introStepBuilder)) {
      _finishedIntroStepBuilderList.add(introStepBuilder);
    }

    if (introStepBuilder.overlayBuilder != null) {
      _overlayWidget = Stack(
        children: [
          Positioned(
            child: SizedBox(
              child: introStepBuilder.overlayBuilder!(
                StepWidgetParams(
                  order: introStepBuilder.order,
                  areButtonsVisible: introStepBuilder.areButtonsVisible,
                  navigationBeforeNextStep: introStepBuilder.navigationBeforeNextStep,
                  onNext: hasNextStep ? render : null,
                  onPrev: hasPrevStep
                      ? () {
                          render(reverse: true);
                        }
                      : null,
                  onFinish: _onFinish,
                  screenSize: _screenSize,
                  size: _widgetSize,
                  offset: _widgetOffset,
                ),
              ),
            ),
            width: position.width,
            left: position.left,
            top: position.top,
            bottom: position.bottom,
            right: position.right,
          ),
        ],
      );
    } else if (introStepBuilder.text != null) {
      _overlayWidget = Stack(
        children: [
          Positioned(
            child: SizedBox(
              width: position.width,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: position.crossAxisAlignment,
                children: [
                  Text(
                    introStepBuilder.text!,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(
                    height: 12,
                  ),
                  IntroButton(
                    text: buttonTextBuilder == null
                        ? 'Next'
                        : buttonTextBuilder!(introStepBuilder.order),
                    onPressed: render,
                  ),
                ],
              ),
            ),
            left: position.left,
            top: position.top,
            bottom: position.bottom,
            right: position.right,
          ),
        ],
      );
    }

    if (_overlayEntry == null) {
      _createOverlay();
    } else {
      _overlayEntry!.markNeedsBuild();
    }
  }

  void _createOverlay() {
    _overlayEntry = new OverlayEntry(
      builder: (BuildContext context) {
        Size currentScreenSize = MediaQuery.of(context).size;

        return _DelayRenderedWidget(
          removed: _removed,
          childPersist: true,
          duration: _animationDuration,
          child: !isVisible ? Container(width: double.maxFinite,
              height: double.maxFinite,
              color: maskColor) : Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    maskColor,
                    BlendMode.srcOut,
                  ),
                  child: Stack(
                    children: [
                      _widgetBuilder(
                        backgroundBlendMode: BlendMode.dstOut,
                        left: 0,
                        top: 0,
                        right: 0,
                        bottom: 0,
                        onTap: maskClosable
                            ? () {
                                Future.delayed(
                                  const Duration(milliseconds: 200),
                                  () {
                                    render();
                                  },
                                );
                              }
                            : null,
                      ),
                      _widgetBuilder(
                        width: _widgetSize.width,
                        height: _widgetSize.height,
                        left: _widgetOffset.dx,
                        top: _widgetOffset.dy,
                        borderRadiusGeometry:
                            _currentIntroStepBuilder?.borderRadius ??
                                borderRadius,
                        onTap: _currentIntroStepBuilder?.onHighlightWidgetTap,
                      ),
                    ],
                  ),
                ),
                _DelayRenderedWidget(
                  duration: _animationDuration,
                  child: _overlayWidget,
                ),
              ],
            ),
          ),
        );
      },
    );
    Overlay.of(_context!)!.insert(_overlayEntry!);
  }

  void start() {
    dispose();
    render();
  }

  void refresh() {
    render(
      isUpdate: true,
    );
  }

  static Intro of(BuildContext context) {
    _context = context;
    return context.dependOnInheritedWidgetOfExactType<Intro>()!;
  }

  void dispose() {
    _onFinish();
  }

  @override
  bool updateShouldNotify(Intro oldWidget) {
    return false;
  }
}
