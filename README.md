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

#### ClearConnection(*string* socket)
Clears and closes the connection for a specific *socket*.

#### ClearAllConnection()
Clears and closes all connections.

## Socket methods
#### Listen(*string* socket, *function* fnc)
Sets a handle to listen a specific *socket*.
_If no connection has been created, create a connection._

#### ListenAll(*function* fnc)
Sets a handle to listen any transmission.

#### Close(*string* socket)
Close the socket.

#### GetStatus(*string* socket)
Get the status of the connection on the socket.

#### Read()
Wait the next received data.

#### Write(*string* socket, *string* msg)
Wait the next received data.




## Other methods
#### Ping()
Send a ping and listen to the responses of nearby constructs.

<!-- How to use -->
# How to use
To use this library in Dual Universe, you can simply copy the lua code and paste it in a Library slot. It can be used to compute transmissions for the [`du-socket`](https://github.com/EliasVilld/du-socket) library. See below an example :
```lua
local player = {
  id = 999,
  name = "Username",
  pos = { 1, 2, 3},
  org = "Org name",
  relation = 0
}

local s = serialize(player) -->  {relation=0,org="Org name",pos={1,2,3},id=999,name="Username"}
local t = deserialize(s)
print(t.name) --> Username

local s = serialize(player,true) -->  {id=999,org=&dq;Org name&dq;,name=&dq;Username&dq;,relation=0,pos={1,2,3}}
local t = deserialize(s)
print(t.name) --> Username
```
Keep in mind that, for Lua arrays have no order. 
