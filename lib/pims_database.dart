part of dart_pims;

/**
 * Annotation to set additional properties of the field.
 * Usage:
 * 
 *   class Person {
 *     @field(-1, true, true, true) // unlimited, is_key, is_unique, is_auto
 *     String ID;
 * 
 *     @field(25, true)             // length, is_key, !is_unique, !is_auto
 *     String fullname;
 *     ...
 *   }
 */
class field {
  final bool is_key;
  final bool is_unique;
  final bool is_auto;
  final int length;
  
  const field([this.length=-1, this.is_key=false, this.is_unique=false, this.is_auto=false]);
}

/**
 * Annotation to set relationship cardinality.
 * Usage:
 * 
 *   class Person {
 *     ...
 *     @relation(1,1)
 *     Person wife;
 * 
 *     @relation(2) // other end's cardinality -1 (means N)
 *     Map<dynamic,Person> descendants;
 * 
 *     @relation(-1,2) //
 *     Map<dynamic,Person> ascendants;
 *   }
 */
class relation {
  final int from;
  final int to;
  
  const relation([this.from=1, this.to=-1]);
}

/**
 * A FieldMirror supplements a VariableMirror with information about the wrapped instance
 * variable when annotated as a field.
 */
@proxy
class FieldMirror {
  static final Map<Type,String> FieldType = {
    bool: 'bit',
    int: 'integer',
    double: 'double',
    String: 'char'
  };
  
  static bool isField ( VariableMirror m )
    => m.metadata.any((md) => md.type.reflectedType is field);
  
  static attributes ( VariableMirror m )
    => m.metadata.where((md) => md.type.reflectedType is field).first.reflectee;  

  VariableMirror _mirror;
  InstanceMirror _metamirror;
  field _attrs;
  
  
  FieldMirror ( VariableMirror mirror ) {
    if ( !isField(mirror) ) throw mirror;
    this._mirror = mirror;
    this._metamirror = reflect(mirror);
    this._attrs = attributes(mirror);
  }
  
  bool get isKey        => this._attrs.is_key;
  bool get isUnique     => this._attrs.is_unique;
  bool get isPrimaryKey => this.isKey && this.isUnique;
  bool get isAuto       => this._attrs.is_auto;
  int  get length       => this._attrs.length > 0 ? this._attrs.length : 0;
  String get name       => MirrorSystem.getName(this._mirror.simpleName);
  String get type       => FieldType[this._mirror.type.reflectedType];
    
  @override
  dynamic noSuchMethod ( Invocation inv ) =>
    this._metamirror.delegate(inv);
}

/**
 * A RelationshipMirror supplements a VariableMirror with information about the wrapped
 * instance variable when annotated as a relationship.
 */
@proxy
class RelationshipMirror {
  static bool is_relationship ( VariableMirror m )
    => m.metadata.any((md) => md.type.reflectedType is relation);
  
  static relation cardinality ( VariableMirror m )
    => m.metadata.where((md) => md.type.reflectedType is relation).first.reflectee;
  
  VariableMirror _mirror;
  InstanceMirror _metamirror;
  relation _card;
  EntityMirror _parent;
  EntityMirror _target;
  
  RelationshipMirror ( VariableMirror mirror ) {
    if ( !is_relationship(mirror) ) throw mirror;
    this._mirror = mirror;
    this._metamirror = reflect(mirror);
    this._card = cardinality(mirror);
    this._parent = new EntityMirror(this._mirror.owner);
    this._target = new EntityMirror(this._mirror.type);
  }
  
  int get fromCard            => this._card.from;
  int get toCard              => this._card.to;
  EntityMirror get fromMirror => this._parent;
  EntityMirror get toMirror   => this._target;
  String get name             => MirrorSystem.getName(this._mirror.simpleName);
  String get ref_name         => this._target.name;
  String get ref_fieldname    => this._target.primary_key.name;
  String get ref_fieldtype    => this._target.primary_key.type;
  
  @override
  dynamic noSuchMethod ( Invocation inv ) =>
    this._metamirror.delegate(inv);
}

/**
 * An EntityMirror supplements a ClassMirror with information about the wrapped class
 * when it contains instance variables annotated as fields or relationships.
 */
@proxy
class EntityMirror {
  ClassMirror _classmirror;
  InstanceMirror _metamirror;
  FieldMirror _pk;
  List<FieldMirror> fields = [];
  List<RelationshipMirror> relations = [];
  
  @field(-1, true, true, true)
  int id;
  
  EntityMirror ( ClassMirror mirror ) {
    this._classmirror = mirror;
    this._metamirror = reflect(mirror);
    
    // Run through all members of the class
    this._classmirror.declarations.values.where(
      (m) => m is VariableMirror).forEach((fm) {
        if ( FieldMirror.isField(fm) ) {
          var nfm = new FieldMirror(fm as VariableMirror);
          if ( nfm.isPrimaryKey ) this._pk = nfm;
          this.fields.add(nfm);
        }
        else if ( RelationshipMirror.is_relationship(fm) ) {
          this.relations.add(new RelationshipMirror(fm as VariableMirror));
        }
    });
    
    // Add a default PK field if there's none
    if ( !this.fields.any((fm) => fm.isPrimaryKey) ) {
      var my_mirror = reflectClass(EntityMirror);
      var pkfm = new FieldMirror(my_mirror.declarations[#id] as VariableMirror);
      this._pk = pkfm;
      this.fields.insert(0, pkfm);
    }
  }
  
  InstanceMirror newInstance ( {List args: null, Map<String, dynamic> kwargs: null} ) {
    // Create instance
    var constructors =
      this._classmirror.declarations.values
        .where((m) => m is MethodMirror && m.isConstructor);
    var instance_mirror =
      this._classmirror.newInstance(constructors.first.simpleName, []);
    
    // Set instance variables if necessary
    if ( kwargs != null ) {
      this.fields.forEach(
        (fm) => instance_mirror.setField(
          fm.simpleName, kwargs[MirrorSystem.getName(fm.simpleName)]));
    } else if ( args != null ){
      var i = 0;
      this.fields.forEach(
        (fm) => instance_mirror.setField(fm.simpleName, args[i++]));
    }
    
    return instance_mirror;
  }
  
  String      get name        => MirrorSystem.getName(this._classmirror.simpleName);
  FieldMirror get primary_key => this._pk;
  
  @override
  dynamic noSuchMethod ( Invocation inv ) =>
    this._metamirror.delegate(inv);
}

EntityMirror reflectEntity ( Type T ) {
  return new EntityMirror(reflectClass(T));
}

abstract class SqlQuery {
  EntityMirror _entity;
  Map<String, dynamic> _filters;
  
  SqlQuery ( EntityMirror entity, [Map<String, dynamic> filters = null] ) {
    this._entity = entity;
    this._filters = filters;
  }
  
  @override
  String toString();
}

class CreateQuery extends SqlQuery {
  String _columns;
  String _restrictions;
  
  static String len_clause(FieldMirror fm) =>
    fm.length > 0 ? '(${fm.length})' : '';
  static String key_clause(FieldMirror fm) =>
    (fm.isUnique ? 'unique' : '') +
    (fm.isPrimaryKey ? 'primary' : '') +
    (fm.isKey ? 'key' : '');
  static String auto_clause(FieldMirror fm) =>
    fm.isAuto ? 'auto_increment' : '';
  
  CreateQuery ( EntityMirror entity )
  : super(entity) {
    var columns = '';
    var restrictions = '';
    entity.fields.forEach((fm) {
      columns +=
        "${fm.name} ${fm.type}${len_clause(fm)} ${key_clause(fm)} ${auto_clause(fm)} ,";
    });
    entity.relations.forEach((rf) {
      columns += "${rf.name} ${rf.ref_type} ,";
      restrictions += "foreign key (${rf.name}) references ${rf.name}(${rf.ref_name}) ,";
    });
    this._columns = columns.substring(0, columns.length-1);
    this._restrictions = restrictions.substring(0, restrictions.length-1);
  }

  String mediatorTableCreate ( RelationshipMirror rm ) =>
      'create table ${this._entity.name}_${rm.ref_name} ('
      '${this._entity.primary_key.name} ${this._entity.primary_key.type}, '
      '${rm.ref_fieldname} ${rm.ref_fieldtype}, '
      'primary key(${this._entity.primary_key.name}, ${rm.ref_fieldname})) '
      'foreign key(${this._entity.primary_key.name}) references ${this._entity.name}, '
      'foreign key(${rm.ref_fieldname}) references ${rm.ref_name}';
  
  @override
  String toString() {
    return 'create table ${this._entity.name} (${this._columns}) ${this._restrictions}';
  }
}

class InsertQuery extends SqlQuery {
  String _columns;
  String _placeholders;
  
  InsertQuery ( EntityMirror entity )
  : super(entity) {
    var columns = '';
    var placeholders = '';
    this._entity.fields.forEach((fm) {
      columns += (fm.name + ',');
      placeholders += "?,";
    });
    this._columns = columns.substring(0, columns.length-1);
    this._placeholders = placeholders.substring(0, placeholders.length-1);
  }
  
  @override
  String toString() {
    return
      'insert into ${this._entity.name} (${this._columns}) values (${this._placeholders})';
  }
}

class UpdateQuery extends SqlQuery {
  String _columns;

  UpdateQuery ( 
    EntityMirror entity, [Map<String, dynamic> filters = null] )
  : super(entity, filters) {
    var columns = '';
    this._entity.fields.where((fm) => !fm.isPrimaryKey).forEach((fm) {
      columns += "${fm.name}=?,";
    });
    this._columns = columns.substring(0, columns.length-1);
  }
  
  @override
  String toString() {
    return
      'update ${this._entity.name} set ${this._columns} where ${this._entity.primary_key.name}=?';
  }  
}

class SelectQuery extends SqlQuery {  
  SelectQuery ( 
    EntityMirror entity, [Map<String, dynamic> filters = null] )
  : super(entity, filters) {
  }
  
  @override
  String toString() {
    return 'select * from ${this._entity.name} where ${this._entity.primary_key.name}=?';
  }  
}

class DeleteQuery extends SqlQuery {
  DeleteQuery ( 
    EntityMirror entity, [Map<String, dynamic> filters = null] )
  : super(entity, filters) {
  }
  
  @override
  String toString() {
    return 'delete from ${this._entity.name} where ${this._entity.primary_key.name}=?';
  }  
}

class SelectRelatedQuery extends SqlQuery {
  RelationshipMirror _rel;
  
  SelectRelatedQuery ( EntityMirror entity, RelationshipMirror rel, [Map<String, dynamic> filters = null] )
  : super(entity, filters) {
    this._rel = rel;
  }
  
  @override
  String toString() {
    return 'select * from ${this._rel.toMirror.name} where ${this._rel.toMirror.primary_key.name}=?';
  }  
}

class Persistent {
  EntityMirror _mirror;
  ConnectionPool _pool;
  Query createquery;
  Query insertquery;
  Query updatequery;
  Query deletequery;
  Query selectquery;
  Query selectallquery;
  Map<String, Query> relatedgetters = {};

  Persistent ( Type T, ConnectionPool pool ) {
    this._mirror = reflectEntity(T);
    this._pool = pool;
    this._pool.prepare(new CreateQuery(_mirror).toString()).then((q) { this.createquery = q; });
    this._pool.prepare(new InsertQuery(_mirror).toString()).then((q) { this.insertquery = q; });
    this._pool.prepare(new UpdateQuery(_mirror).toString()).then((q) { this.updatequery = q; });
    this._pool.prepare(new DeleteQuery(_mirror).toString()).then((q) { this.deletequery = q; });
    this._pool.prepare(new SelectQuery(_mirror).toString()).then((q) { this.selectquery = q; });
    _mirror.relations.forEach((rm) {
      this._pool.prepare(
        new SelectRelatedQuery(_mirror, rm).toString())
        .then((q) { this.relatedgetters[rm.name] = q; });
    });
  }
  
  Future create ( Map<String, dynamic> values ) {
    var query_args = new List();
    this._mirror.declarations.values
      .where((m) => m is VariableMirror)
      .forEach((f) => query_args.add(values[f]));
    return this.insertquery.execute(query_args).then(
      (res) => this._mirror.newInstance(kwargs: values).reflectee,
      onError: (err) => null);
  }
  
  Future delete ( obj ) {
    if ( obj.runtimeType != this._mirror._classmirror.reflectedType ) throw obj;
    return this.deletequery.execute([obj.id]).then(
      (res) => res,
      onError: (err) => null);
  }
  
  Future update ( obj ) {
    if ( obj.runtimeType != this._mirror._classmirror.reflectedType ) throw obj;
    var query_args = new List();
    var instance_mirror = reflect(obj);
    this._mirror.fields.forEach(
      (fm) => query_args.add(instance_mirror.getField(fm.simpleName).reflectee));
    return this.updatequery.execute(query_args).then(
      (res) => res,
      onError: (err) => null);
  }
  
  Future get ( dynamic id ) {
    return this.selectquery.execute([id])
      .then((res) => res.first.then(
        (row) => this._mirror.newInstance(args: row).reflectee,
        onError: (err) => null),
      onError: (err) => null);
  }
  
  Future getAll() {
    return this.selectallquery.execute()
      .then((res) => res.map((row) => this._mirror.newInstance(args: row)));
  }
  
  @override
  dynamic noSuchMethod ( Invocation inv ) {
    var invname = inv.memberName.toString();
    if ( inv.isMethod && invname.startsWith("get") ) {
      var relname = invname.substring(3);
      if ( relname != null && relname.length > 0 ) {
        try {
          var relmirror = _mirror.relations.firstWhere((rel) => rel.name == relname);
          Future<Results> result =
            this.relatedgetters[relname].execute([inv.positionalArguments[0]]);
          if ( relmirror.toCard == 1) {
            result.then(
              (res) => res.first.then(
                (row) => relmirror.toMirror.newInstance(args: row),
                onError: (err) => null),
              onError: (err) => null);
          } else {
            result.then(
              (res) => res.map((row) => relmirror.toMirror.newInstance(args: row)));
          }
          return result;
        }
        catch ( StateError ) {
           // No relationship with the given name exists
        }
      }
    }
    
    return super.noSuchMethod(inv);
  }
}
