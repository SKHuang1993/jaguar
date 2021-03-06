library test.jaguar.intercept.before;

import 'package:http/http.dart' as http;
import 'dart:math';
import 'package:jaguar_resty/jaguar_resty.dart' as resty;
import 'package:test/test.dart';
import 'package:jaguar/jaguar.dart';
import 'package:jaguar_reflect/jaguar_reflect.dart';

final Random rand = new Random.secure();

void genRandom(Context ctx) {
  ctx.addVariable(rand.nextInt(1000), id: 'randomInt');
}

void doublesRandom(Context ctx) {
  int randomInt = ctx.getVariable<int>(id: 'randomInt');
  ctx.addVariable(randomInt * 2, id: 'doubledRandomInt');
}

@Controller()
class ExampleController {
  @GetJson(path: '/two')
  @Intercept(const [genRandom, doublesRandom])
  Map two(Context ctx) => {
        'Random': ctx.getVariable<int>(id: 'randomInt'),
        'Doubled': ctx.getVariable<int>(id: 'doubledRandomInt'),
      };
}

void main() {
  resty.globalClient = new http.IOClient();

  group('Custom interceptor:Generated', () {
    Jaguar server;
    setUpAll(() async {
      server = new Jaguar(port: 8000);
      server..add(reflect(new ExampleController()));
      await server.serve();
    });

    tearDownAll(() async {
      await server.close();
    });

    test(
        'one interceptor',
        () => resty
                .get('/two')
                .origin('http://localhost:8000')
                .exact(statusCode: 200, mimeType: 'application/json')
                .decode<Map>()
                .then((Map body) {
              expect(body['Random'] * 2, body['Doubled']);
            }));
  });
}
