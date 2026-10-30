import 'dart:async';
import 'dart:convert';

import 'package:crowdradar/configs/generic_response.dart';
import 'package:crowdradar/cubits/favorites/favorites_cubit.dart';
import 'package:crowdradar/cubits/favorites/favorites_state.dart';
import 'package:crowdradar/cubits/places/place_detail_cubit.dart';
import 'package:crowdradar/models/place_model.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/services/place_service.dart';
import 'package:crowdradar/services/push_device_service.dart';
import 'package:crowdradar/services/push_message_guard.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const place = PlaceModel(
  id: 7,
  nombre: 'Parque QA',
  categoria: 'Parque',
  latitud: -12,
  longitud: -77,
  demostrativo: false,
  esFavorito: true,
);
const placeJson = {
  'id': 7,
  'nombre': 'Parque QA',
  'categoria': 'Parque',
  'latitud': -12,
  'longitud': -77,
  'demostrativo': false,
  'esFavorito': true,
};
void login([int id = 1]) => SessionService.start(
  token: 'same-test-token',
  user: UserModel(id: id),
);

class PendingFavorites extends PlaceService {
  final mutation = Completer<GenericResponse<bool>>();
  int loads = 0, removes = 0, adds = 0;
  @override
  Future<GenericResponse<List<PlaceModel>>> getFavorites() async {
    loads++;
    return const GenericResponse(success: true, data: [place]);
  }

  @override
  Future<GenericResponse<PlaceModel>> getPlace(int id) async =>
      const GenericResponse(success: true, data: place);
  @override
  Future<GenericResponse<bool>> removeFavorite(int id) {
    removes++;
    return mutation.future;
  }

  @override
  Future<GenericResponse<bool>> addFavorite(int id) {
    adds++;
    return mutation.future;
  }
}

void main() {
  setUp(() {
    SessionService.clear();
    login();
  });
  tearDown(SessionService.clear);
  final operations =
      <String, Future<GenericResponse<dynamic>> Function(PlaceService)>{
        'listar': (s) => s.getFavorites(),
        'agregar': (s) => s.addFavorite(7),
        'eliminar': (s) => s.removeFavorite(7),
      };
  for (final operation in operations.entries) {
    test('${operation.key}: 401 vigente sin JSON rechaza sesión', () async {
      await http.runWithClient(() async {
        final result = await operation.value(PlaceService());
        expect(result.success, isFalse);
        expect(SessionService.isAuthenticated, isFalse);
        expect(SessionService.wasRejected, isTrue);
      }, () => MockClient((_) async => http.Response('no-json', 401)));
    });
    for (final failure in ['503', 'red', 'timeout']) {
      test('${operation.key}: $failure conserva sesión', () async {
        await http.runWithClient(
          () async {
            expect((await operation.value(PlaceService())).success, isFalse);
            expect(SessionService.isAuthenticated, isTrue);
            expect(SessionService.wasRejected, isFalse);
          },
          () => MockClient((_) async {
            if (failure == 'red') throw http.ClientException('offline');
            if (failure == 'timeout') throw TimeoutException('timeout');
            return http.Response('no-json', 503);
          }),
        );
      });
    }
    for (final change in ['otra cuenta', 'misma cuenta', 'logout']) {
      test(
        '${operation.key}: 401 antiguo tras $change no rechaza sesión nueva',
        () async {
          final response = Completer<http.Response>();
          await http.runWithClient(() async {
            final pending = operation.value(PlaceService());
            await Future<void>.delayed(Duration.zero);
            if (change == 'logout') {
              SessionService.clear();
            } else {
              login(change == 'otra cuenta' ? 2 : 1);
            }
            response.complete(http.Response('', 401));
            expect((await pending).success, isFalse);
            expect(SessionService.isAuthenticated, change != 'logout');
            expect(SessionService.wasRejected, isFalse);
            if (change != 'logout') {
              expect(
                SessionService.currentUser?.id,
                change == 'otra cuenta' ? 2 : 1,
              );
            }
          }, () => MockClient((_) => response.future));
        },
      );
    }
    test(
      '${operation.key}: éxito tardío tras cuenta nueva se descarta',
      () async {
        final response = Completer<http.Response>();
        await http.runWithClient(() async {
          final pending = operation.value(PlaceService());
          await Future<void>.delayed(Duration.zero);
          login(2);
          response.complete(
            operation.key == 'listar'
                ? http.Response(
                    jsonEncode({
                      'data': [placeJson],
                    }),
                    200,
                  )
                : operation.key == 'agregar'
                ? http.Response('{"data":{"placeId":7,"esFavorito":true}}', 201)
                : http.Response('', 204),
          );
          expect((await pending).success, isFalse);
          expect(SessionService.currentUser?.id, 2);
        }, () => MockClient((_) => response.future));
      },
    );
  }
  test('agregar no acepta confirmación para otro lugar', () async {
    await http.runWithClient(
      () async {
        expect((await PlaceService().addFavorite(7)).success, isFalse);
      },
      () => MockClient(
        (_) async =>
            http.Response('{"data":{"placeId":8,"esFavorito":true}}', 201),
      ),
    );
  });
  test('duplicado recibe mensaje fijo y estado reconocible', () async {
    await http.runWithClient(
      () async {
        final result = await PlaceService().addFavorite(7);
        expect(result.error, PlaceService.favoriteAlreadyExists);
        expect(result.message, 'Este lugar ya pertenece a tus favoritos.');
      },
      () => MockClient(
        (_) async => http.Response(
          '{"code":"FAVORITE_ALREADY_EXISTS","message":"private internal details"}',
          409,
        ),
      ),
    );
  });
  test('lista limpia inmediatamente al cambiar cuenta sin logout', () async {
    final service = PendingFavorites();
    final cubit = FavoritesCubit(service);
    addTearDown(cubit.close);
    await cubit.loadFavorites();
    expect(cubit.state, isA<FavoritesLoaded>());
    login(2);
    expect(cubit.state, isA<FavoritesInitial>());
  });
  test('eliminar bloquea doble envío y refresh durante escritura', () async {
    final service = PendingFavorites();
    final cubit = FavoritesCubit(service);
    addTearDown(cubit.close);
    await cubit.loadFavorites();
    final pending = cubit.removeFavorite(7);
    expect(await cubit.removeFavorite(7), isNull);
    await cubit.loadFavorites();
    expect(service.loads, 1);
    expect(service.removes, 1);
    service.mutation.complete(const GenericResponse(success: true, data: true));
    expect((await pending)?.success, isTrue);
    expect((cubit.state as FavoritesLoaded).places, isEmpty);
  });
  test('eliminar tardío tras cambio de cuenta no repone favoritos', () async {
    final service = PendingFavorites();
    final cubit = FavoritesCubit(service);
    addTearDown(cubit.close);
    await cubit.loadFavorites();
    final pending = cubit.removeFavorite(7);
    login(2);
    service.mutation.complete(const GenericResponse(success: true));
    expect(await pending, isNull);
    expect(cubit.state, isA<FavoritesInitial>());
  });
  test(
    'detalle bloquea doble envío y actualiza estado para agregar de nuevo',
    () async {
      final service = PendingFavorites();
      final cubit = PlaceDetailCubit(service, 7);
      addTearDown(cubit.close);
      await cubit.loadPlace();
      final pending = cubit.toggleFavorite();
      expect(await cubit.toggleFavorite(), isNull);
      expect(service.removes, 1);
      service.mutation.complete(const GenericResponse(success: true));
      await pending;
      expect((cubit.state as PlaceDetailLoaded).place.esFavorito, isFalse);
      await cubit.toggleFavorite();
      expect(service.adds, 1);
      expect((cubit.state as PlaceDetailLoaded).place.esFavorito, isTrue);
    },
  );
  test('guardia push exige usuario, binding vigente y lugar válido', () {
    final data = {'userId': '1', 'placeId': '7', 'registrationId': 'current'};
    expect(authorizedPushPlace(data, 'current'), 7);
    expect(authorizedPushPlace(data, 'old'), isNull);
    expect(authorizedPushPlace({...data, 'userId': '2'}, 'current'), isNull);
    expect(authorizedPushPlace({...data, 'placeId': '0'}, 'current'), isNull);
    expect(
      authorizedPushPlace({...data, 'placeId': '2147483648'}, 'current'),
      isNull,
    );
    SessionService.clear();
    expect(authorizedPushPlace(data, 'current'), isNull);
  });
  test(
    'registro push conserva binding de servidor y aplica 401 vigente',
    () async {
      await http.runWithClient(
        () async {
          final id = await PushDeviceService().register(
            sessionToken: SessionService.token!,
            deviceToken: 'test-fid',
            platform: 'web',
            generation: SessionService.generation,
          );
          expect(id, 'test-registration');
        },
        () => MockClient((request) async {
          expect(jsonDecode(request.body), {
            'token': 'test-fid',
            'platform': 'web',
          });
          return http.Response(
            '{"data":{"registrationId":"test-registration"}}',
            200,
          );
        }),
      );
      await http.runWithClient(() async {
        await expectLater(
          PushDeviceService().register(
            sessionToken: SessionService.token!,
            deviceToken: 'test-fid',
            platform: 'web',
            generation: SessionService.generation,
          ),
          throwsStateError,
        );
        expect(SessionService.isAuthenticated, isFalse);
      }, () => MockClient((_) async => http.Response('', 401)));
    },
  );
  test('baja push envía binding exacto de la sesión capturada', () async {
    await http.runWithClient(
      () async {
        await PushDeviceService().unregister(
          sessionToken: SessionService.token!,
          deviceToken: 'test-fid',
          registrationId: 'old-binding',
        );
      },
      () => MockClient((request) async {
        expect(jsonDecode(request.body), {
          'token': 'test-fid',
          'registrationId': 'old-binding',
        });
        return http.Response('', 204);
      }),
    );
  });
  test('401 push antiguo no invalida nueva sesión con igual JWT', () async {
    final response = Completer<http.Response>();
    await http.runWithClient(() async {
      final pending = PushDeviceService().register(
        sessionToken: SessionService.token!,
        deviceToken: 'test-fid',
        platform: 'web',
        generation: SessionService.generation,
      );
      final expectation = expectLater(pending, throwsStateError);
      login(2);
      response.complete(http.Response('', 401));
      await expectation;
      expect(SessionService.currentUser?.id, 2);
      expect(SessionService.isAuthenticated, isTrue);
    }, () => MockClient((_) => response.future));
  });
}
