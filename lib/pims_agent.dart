library dart_pims;

import 'dart:async';

@MirrorsUsed(symbols: '*', override: '*')
import 'dart:mirrors';

import 'package:logging/logging.dart' show Logger, Level, LogRecord;
import 'package:sqljocky/sqljocky.dart' show ConnectionPool, Query, Result, Results;

part 'pims_model.dart';
part 'pims_database.dart';

final Logger log = new Logger('pims_agent');

class PimsAgent {
  final Map<int, String> streams = {};
  Persistent _user, _message, _conversation;
  ConnectionPool _connection;
  StreamController<Map> _logon_stream;
  
  PimsAgent ( ConnectionPool conn ) {
    this._connection = conn;
    this._user = new Persistent(User, conn);
    this._message = new Persistent(Message, conn);
    this._conversation = new Persistent(Conversation, conn);
  }
  
  Stream<Map> handle ( json ) {
    switch ( json['request'] ) {
      case 'register':
        // Initiate user registration
        return this.register(json['args']);
        
      case 'logon':
        // Log user on
        return this.logon(json['args']);
        
      case 'logoff':
        // Log user off
        return this.logoff(json['args']);
        
      case 'message':
        // Receive message
        return this.message(json['args']);
        
      case 'openstream':
        // Initiate a new stream connection
        return this.openstream(json['args']);
        
      case 'closestream':
        // Shut-down a stream connection
        return this.closestream(json['args']);
        
      case 'streamchunk':
        // Receive a chunk for an existing stream
        return this.streamchunk(json['args']);
        
      default:
        log.warning("Unknown request: ${json['request']}");
        return null;
    }    
  }
  
  Stream<Map> register ( json ) {
    String uname = json['username'];
    String pwd = json['password'];
    String name = json['name'];
    String email = json['email'];
    String picture = json['picture'];
    String phonenr = json['phonenr'];
    
    return this._user.create({
      'username': uname,
      'password': pwd,
      'name': name,
      'email': email,
      'picture': picture,
      'phonenr': phonenr
    }).then(
      (user) => { 'result': 200 },
      onError: (error) => { 'result': 400 }).asStream();
  }
  
  Stream<Map> logon ( json ) {
    String uname = json['username'];
    String pwd = json['password'];
    if ( this._logon_stream == null ) {
      this._logon_stream = new StreamController<Map>();
    }
    
    this._user.get(uname).then((user) {
      this._logon_stream.add({ 'result': user.password == pwd ? 200 : 403 });
      if ( user.password != pwd ) {
        this._logon_stream.close();
        this._logon_stream = null;
      }
    });
    
    return this._logon_stream.stream;    
  }
  
  Stream<Map> logoff ( json ) {
    
  }
  
  Stream<Map> message ( json ) {
    
  }
  
  Stream<Map> openstream ( json ) {
    
  }
  
  Stream<Map> closestream ( json ) {
    
  }
  
  Stream<Map> streamchunk ( json ) {
    
  }
}