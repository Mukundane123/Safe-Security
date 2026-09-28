import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../repositories/repository.dart';
import 'auth_controller.dart';

extension ContextX on BuildContext {
  IRepository get repo => read<IRepository>();
  AuthController get auth => read<AuthController>();
}