import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../platform/browser_history.dart';
import 'information_content.g.dart';

/// Only public route names and section identifiers enter URLs or history state.
/// Drafts, report contents and session keys remain with their controllers.
@immutable
class AppLocation {
  const AppLocation(this.name, {this.section});
  final String name;
  final String? section;

  Uri get uri => Uri(
    path: name.isEmpty ? '/' : '/$name',
    queryParameters: section == null ? null : {'section': section!},
  );

  static AppLocation? parse(Uri uri) {
    if (uri.hasScheme || uri.hasAuthority) return null;
    final name = uri.path.replaceAll(RegExp(r'^/|/$'), '');
    if (name != '' &&
        name != 'settings' &&
        !informationContent.containsKey(name)) {
      return null;
    }
    final section = uri.queryParameters['section'];
    if (section != null) {
      final sections = informationContent[name]?['sections'] as List<dynamic>?;
      if (sections == null ||
          !sections.any((entry) => entry['id'] == section)) {
        return null;
      }
    }
    return AppLocation(name, section: section);
  }
}

@immutable
class AppRouteState {
  const AppRouteState(this.locations, {this.historyDepth = 0});
  final List<AppLocation> locations;
  final int historyDepth;
  AppLocation get current => locations.last;

  static AppRouteState fromInformation(RouteInformation information) {
    final current = AppLocation.parse(information.uri) ?? const AppLocation('');
    final state = information.state;
    if (state is Map && state['worthhitRoutes'] is List) {
      final paths = state['worthhitRoutes'] as List;
      final depth = state['depth'];
      if (paths.isNotEmpty &&
          paths.length <= 32 &&
          depth is int &&
          depth >= 0 &&
          depth < 32) {
        final routes = <AppLocation>[];
        for (final path in paths) {
          final route = path is String && path.length < 120
              ? AppLocation.parse(Uri.tryParse(path) ?? Uri(path: 'invalid'))
              : null;
          if (route == null || route.uri.toString() != path) break;
          routes.add(route);
        }
        if (routes.length == paths.length &&
            routes.first.name.isEmpty &&
            routes.skip(1).every((route) => route.name.isNotEmpty) &&
            routes.last.uri == current.uri &&
            depth <= routes.length - 1) {
          return AppRouteState(List.unmodifiable(routes), historyDepth: depth);
        }
      }
    }
    return AppRouteState([
      const AppLocation(''),
      if (current.name.isNotEmpty) current,
    ]);
  }

  RouteInformation get information => RouteInformation(
    uri: current.uri,
    state: {
      'worthhitRoutes': [for (final route in locations) route.uri.toString()],
      'depth': historyDepth,
    },
  );
}

class AppRouteParser extends RouteInformationParser<AppRouteState> {
  const AppRouteParser();

  @override
  Future<AppRouteState> parseRouteInformation(
    RouteInformation routeInformation,
  ) => SynchronousFuture(AppRouteState.fromInformation(routeInformation));

  @override
  RouteInformation restoreRouteInformation(AppRouteState configuration) =>
      configuration.information;
}

class AppNavigation extends InheritedWidget {
  const AppNavigation({
    super.key,
    required this.open,
    required this.back,
    required super.child,
  });
  final void Function(AppLocation route) open;
  final VoidCallback back;

  static AppNavigation? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppNavigation>();

  @override
  bool updateShouldNotify(AppNavigation oldWidget) => true;
}

class WorthhitRouter extends RouterDelegate<AppRouteState>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<AppRouteState> {
  WorthhitRouter({
    required this.workspaceBuilder,
    required this.settingsBuilder,
    required this.informationBuilder,
    this.browserBack = goBackInBrowser,
  });
  final WidgetBuilder workspaceBuilder;
  final WidgetBuilder settingsBuilder;
  final Widget Function(BuildContext, AppLocation) informationBuilder;
  final bool Function() browserBack;
  @override
  final navigatorKey = GlobalKey<NavigatorState>();
  AppRouteState _state = const AppRouteState([AppLocation('')]);
  bool _traversingHistory = false;

  @override
  AppRouteState get currentConfiguration => _state;

  @override
  Future<void> setNewRoutePath(AppRouteState configuration) {
    _state = configuration;
    _traversingHistory = false;
    return SynchronousFuture(null);
  }

  LocalKey _pageKey(int index) =>
      ValueKey('$index:${_state.locations[index].uri}');

  void _open(BuildContext context, AppLocation destination) {
    if (_traversingHistory || _state.current.uri == destination.uri) return;
    // At the bounded stack limit, replace the last information page. This keeps
    // serialized history small without discarding the retained workspace.
    void change() {
      _state = _state.locations.length < 32
          ? AppRouteState([
              ..._state.locations,
              destination,
            ], historyDepth: _state.historyDepth + 1)
          : AppRouteState([
              ..._state.locations.take(31),
              destination,
            ], historyDepth: _state.historyDepth);
      notifyListeners();
    }

    if (_state.locations.length < 32) {
      Router.navigate(context, change);
    } else {
      Router.neglect(context, change);
    }
  }

  void _back(BuildContext context) {
    if (_state.locations.length <= 1 || _traversingHistory) return;
    if (_state.historyDepth > 0) {
      _traversingHistory = true;
      if (browserBack()) return;
      _traversingHistory = false;
    }
    Router.neglect(context, () {
      _state = AppRouteState(
        _state.locations.sublist(0, _state.locations.length - 1),
        historyDepth: _state.historyDepth > 0 ? _state.historyDepth - 1 : 0,
      );
      notifyListeners();
    });
  }

  @override
  Widget build(BuildContext context) => AppNavigation(
    open: (location) => _open(context, location),
    back: () => _back(context),
    child: Navigator(
      key: navigatorKey,
      pages: [
        MaterialPage<void>(
          key: _pageKey(0),
          name: '/',
          child: ExcludeFocus(
            excluding: _state.locations.length != 1,
            child: Builder(builder: workspaceBuilder),
          ),
        ),
        for (final (index, location) in _state.locations.indexed.skip(1))
          MaterialPage<void>(
            key: _pageKey(index),
            name: '${location.uri}',
            child: ExcludeFocus(
              excluding: index != _state.locations.length - 1,
              child: Builder(
                builder: (context) => location.name == 'settings'
                    ? settingsBuilder(context)
                    : informationBuilder(context, location),
              ),
            ),
          ),
      ],
      onDidRemovePage: (page) {
        // Declarative removals from browser Back have already changed _state.
        // Only an imperative/native pop of the current page needs traversal.
        if (_state.locations.length > 1 &&
            page.key == _pageKey(_state.locations.length - 1)) {
          _back(context);
        }
      },
    ),
  );
}
