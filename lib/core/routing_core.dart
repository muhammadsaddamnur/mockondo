import 'package:get/get.dart';
import 'package:mockondo/core/generate_core.dart';
import 'package:mockondo/core/mock_model.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_router/shelf_router.dart' as shelf_router;

class RoutingCore {
  static shelf_router.Router getRouter(String method, MockModel mockModel) {
    final rules = mockModel.rules ?? [];
    final pagination = rules.firstWhereOrNull(
      (e) => e.type == RulesType.pagination,
    );

    final responseBody = mockModel.responseBody;

    switch (method) {
      case 'GET':
        return shelf_router.Router()
          ..get(mockModel.endpoint, (shelf.Request request) async {
            final body =
                pagination == null
                    ? responseBody
                    : GenerateCore.pagination(
                      request: request,
                      responseBody: responseBody,
                      pagination: pagination,
                    );

            await Future.delayed(Duration(milliseconds: mockModel.delay ?? 0));
            return shelf.Response(
              mockModel.statusCode,
              headers: mockModel.responseHeader,
              body: body,
            );
          });
      case 'POST':
        return shelf_router.Router()
          ..post(mockModel.endpoint, (shelf.Request request) async {
            await Future.delayed(Duration(milliseconds: mockModel.delay ?? 0));
            return shelf.Response(
              mockModel.statusCode,
              headers: mockModel.responseHeader,
              body: responseBody,
            );
          });
      case 'PUT':
        return shelf_router.Router()
          ..put(mockModel.endpoint, (shelf.Request request) async {
            await Future.delayed(Duration(milliseconds: mockModel.delay ?? 0));
            return shelf.Response(
              mockModel.statusCode,
              headers: mockModel.responseHeader,
              body: responseBody,
            );
          });
      case 'PATCH':
        return shelf_router.Router()
          ..patch(mockModel.endpoint, (shelf.Request request) async {
            await Future.delayed(Duration(milliseconds: mockModel.delay ?? 0));
            return shelf.Response(
              mockModel.statusCode,
              headers: mockModel.responseHeader,
              body: responseBody,
            );
          });
      case 'DELETE':
        return shelf_router.Router()
          ..delete(mockModel.endpoint, (shelf.Request request) async {
            await Future.delayed(Duration(milliseconds: mockModel.delay ?? 0));
            return shelf.Response(
              mockModel.statusCode,
              headers: mockModel.responseHeader,
              body: responseBody,
            );
          });
      default:
        return shelf_router.Router()
          ..get(mockModel.endpoint, (shelf.Request request) async {
            await Future.delayed(Duration(milliseconds: mockModel.delay ?? 0));
            return shelf.Response.ok('This is custom route');
          });
    }
  }
}
