part of dart_pims_server;

var HTTP_SERVER = {
    'host': InternetAddress.ANY_IP_V4,
    'port': 9225
};

var DATABASE = {
    'engine'  : 'mysql',
    'host'    : '127.0.0.1',
    'port'    : 3306,
    'user'    : 'pims',
    'password': 'pims',
    'db'      : 'pims',
    'poolsize': 5
};

