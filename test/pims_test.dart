library pims_test;

@MirrorsUsed(symbols: '*', override: '*')
import 'dart:mirrors';

import 'package:unittest/unittest.dart';
import 'package:dart_pims_server/pims_agent.dart';

class TestClass1 {
  @field()
  bool bool_field;
  
  @field(5)
  double double_field;
}

class TestClass2 {
  @field(10)
  int num_field;
  
  @field(256, false, true)
  String char_field;
  
  @relation(1,1)
  TestClass1 test_class_rel;
}

void main() {
  group('pims_database', () {
    group('decorators', () {
      test('field', () {
        var f = new field();
        expect(f.length == -1 && !f.is_key && !f.is_unique && !f.is_auto, isTrue);
                
        f = new field(10);
        expect(f.length == 10 && !f.is_key && !f.is_unique && !f.is_auto, isTrue);
        
        f = new field(20, true);
        expect(f.length == 20 && f.is_key && !f.is_unique && !f.is_auto, isTrue);
        
        f = new field(30, true, true);
        expect(f.length == 30 && f.is_key && f.is_unique && !f.is_auto, isTrue);
        
        f = new field(40, true, true, true);
        expect(f.length == 40 && f.is_key && f.is_unique && f.is_auto, isTrue);
      });
      test('relation', () {
        var r = new relation();
        expect(r.from == -1 && r.to == -1, isTrue);

        r = new relation(1);
        expect(r.from == 1 && r.to == -1, isTrue);

        r = new relation(1, 2);
        expect(r.from == 1 && r.to == 2, isTrue);
      });
    });
    group('mirrors', () {
      test('FieldMirror', () {
        var cm = reflectClass(TestClass2);
        List<VariableMirror> fields = cm.declarations.values.where((m) => m is VariableMirror);

      });
      test('RelationshipMirror', () {
        var cm = reflectClass(TestClass2);
        List<VariableMirror> fields = cm.declarations.values.where((m) => m is VariableMirror);
        
      });
      test('EntityMirror', () {
        var em = reflectEntity(TestClass2);
        
      });
    });
    group('Persistent', () {
      test('create', () {
        
      });
      test('insert', () {
        
      });
      test('update', () {
        
      });
      test('get', () {
        
      });
      test('get_related', () {
        
      });
      test('delete', () {
        
      });
    });
  });
}