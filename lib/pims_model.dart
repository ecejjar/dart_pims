part of dart_pims;

class User {
  @field(50)
  String name;
  
  @field(20,true,true)
  String username;
  
  @field(20)
  String password;
  
  @field(50,false,true)
  String email;
  
  @field(100)
  String picture;
  
  @field(20)
  String phonenr;
}

class Message {
  @relation(1,1)
  User from;
  
  @field()
  String txt;
  
  @field(256)
  Uri media;
}

class Conversation {
  @relation()
  User peers;
  
  @relation()
  Message msgs;
}
