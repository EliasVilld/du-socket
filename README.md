<!-- Introduction -->
# du-socket
A Lua library designed to allow communication between constructs in the Dual Universe game.

In order to be used, this library requires a connection to :
 - Core Unit
 - Emitter
 - Receiver

<!--List of methods and explanation -->
# Documentation
Description
## Connection methods
#### CreateConnection(*string* socket)
Create a connection for a specific *socket*.

------------
#### ClearConnection(*string* socket)
Clears and closes the connection for a specific *socket*.

------------
#### ClearAllConnection()
Clears and closes all connections.

## Socket methods
#### Listen(*string* socket, *function* fnc)
> Sets a handle to listen a specific *socket*.
_If no connection has been created, create a connection._

------------
#### ListenAll(*function* fnc)
> Sets a handle to listen any transmission.

------------
#### Close(*string* socket)
> Close the socket.

------------
#### GetStatus(*string* socket)
Get the status of the connection on the socket.

------------
#### Read()
> Wait the next received data.

------------
#### Write(*string* socket, *string* msg)
> Wait the next received data.




## Other methods
#### Ping()
> Send a ping and listen to the responses of nearby constructs.


<!-- How to use -->
# How to use
