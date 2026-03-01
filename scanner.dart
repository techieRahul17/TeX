import 'dart:mirrors';
import 'package:email_otp/email_otp.dart';

void main() {
  ClassMirror cm = reflectClass(EmailOTP);
  for (var d in cm.declarations.values) {
    if (d is MethodMirror && d.simpleName == Symbol('setTemplate')) {
      for (var p in d.parameters) {
        String pName = MirrorSystem.getName(p.simpleName);
        print(pName);
      }
    }
  }
}
