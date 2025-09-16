import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppHeader extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final String? chatTitle;
  final VoidCallback? onBackPressed;
  final VoidCallback? onMenuPressed;
  final VoidCallback? onDetailPressed;
  final VoidCallback? onProfilePressed;
  final List<Widget>? actions;
  final bool centerTitle;
  final double elevation;
  final Widget? titleWidget;
  final Widget? searchBar;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double height;
  final PreferredSizeWidget? bottom;
  final bool isTransparent;
  final EdgeInsetsGeometry? titlePadding;
  final bool isInChat;

  const AppHeader({
    super.key,
    this.title = 'ListenIQ',
    this.chatTitle,
    this.onBackPressed,
    this.onMenuPressed,
    this.onDetailPressed,
    this.onProfilePressed,
    this.actions,
    this.centerTitle = true,
    this.elevation = 0,
    this.titleWidget,
    this.searchBar,
    this.backgroundColor,
    this.foregroundColor,
    this.height = kToolbarHeight,
    this.bottom,
    this.isTransparent = false,
    this.titlePadding,
    this.isInChat = false,
  });

  @override
  State<AppHeader> createState() => _AppHeaderState();

  @override
  Size get preferredSize {
    final bottomHeight = bottom?.preferredSize.height ?? 0.0;
    return Size.fromHeight(height + bottomHeight);
  }
}

class _AppHeaderState extends State<AppHeader> {
  @override
  Widget build(BuildContext context) {
    Widget leadingWidget = IconButton(
      icon: Icon(
        widget.isInChat
            ? CupertinoIcons.back
            : CupertinoIcons.line_horizontal_3,
        color: Colors.white,
        size: 24,
      ),
      onPressed: widget.isInChat ? widget.onBackPressed : widget.onMenuPressed,
    );

    Widget titleContent;
    if (widget.searchBar != null) {
      titleContent = Padding(
        padding:
            widget.titlePadding ?? const EdgeInsets.symmetric(horizontal: 8.0),
        child: widget.searchBar!,
      );
    } else if (widget.titleWidget != null) {
      titleContent = widget.titleWidget!;
    } else {
      titleContent = Text(
        widget.isInChat ? (widget.chatTitle ?? 'Chat') : widget.title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: widget.foregroundColor ?? Colors.white,
          letterSpacing: -0.5,
        ),
      );
    }

    return AppBar(
      elevation: widget.elevation,
      centerTitle: widget.searchBar != null ? false : widget.centerTitle,
      backgroundColor: widget.backgroundColor ?? const Color(0xFF1A1A1A),
      foregroundColor: widget.foregroundColor ?? Colors.white,
      leadingWidth: 48,
      leading: leadingWidget,
      title: titleContent,
      actions: [if (widget.actions != null) ...widget.actions!],
      toolbarHeight: widget.height,
      automaticallyImplyLeading: false,
      shape: widget.elevation > 0
          ? const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            )
          : null,
      titleSpacing: 0.0,
      titleTextStyle: TextStyle(
        color: widget.foregroundColor ?? Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: widget.isTransparent
            ? Brightness.light
            : Brightness.light,
        statusBarBrightness: widget.isTransparent
            ? Brightness.dark
            : Brightness.dark,
      ),
      bottom: widget.bottom,
    );
  }
}
