
function Sockets( emit, recv)
    local self = {}
    local _key = math.random(255)
    
    self.Emitter = emit
    self.Receiver = recv
       
    self.WaitPing = false    
    self.Connections = {}
    

    for k,v in pairs(unit) do
        if type(v) == 'table' and v.getElementClass then
            local class = v.getElementClass()

            if class:find('^CoreUnit') then core = v end
        end
    end
    
    self.Id = tostring(core.getConstructId())
    
    
    --=================================== Connection Methods =========================================
    --Create connection
    function self.CreateConnection( socket)
        -- Check if existing connection
        if self.Connections[socket] then
            self.Connections[socket] = nil
        end
        local c = {
            Socket = socket,
            Status = "CLOSED",
            Listening = false,
            Connected = false,
            AckKey = -1,
            SynKey = -1,
            Handler = nil
        }
        
        self.Connections[socket] = c
        
        return c
    end

    --Clear connection
    function self.ClearConnection( socket)
        self.Close( socket)
        self.Connections[socket] = nil
    end

    --Clear connection
    function self.ClearAllConnection()
        self.Connections = nil
    end


    --================================ Socket Methods =======================================
    --Create a listen hangler on socket
    function self.Listen( socket, fnc)
        print('Connection creation : ' .. socket)
        if not self.Connections[socket] then self.CreateConnection( socket) end

        local c = self.Connections[socket]
        c.Handler = coroutine.create( fnc)
        coroutine.resume( c.Handler, socket)

        c.Listening = true
        return handler
    end


    --Create a listen handler for any transmission
    function self.ListenAll( fnc)
        return self.Listen( "*", fnc)
    end


    --Close the connection on the socket
    function self.Close( socket)
        local c = self.Connections[socket]
        c.Handler = nil
        c.Listening = false
        c.Status = "CLOSED"
        c.Connected = false
        
        print("Connection with "..socket .. " closed.")
    end


    --Returns connection status
    function self.GetStatus( socket)
        if not self.Connections[socket] then return "dead" end
        if not self.Connections[socket].Handler then return "dead" end

        return coroutine.status( self.Connections[socket].Handler)
    end


    --Wait for data on the socket, useless infact
    function self.Read()
        return coroutine.yield()
    end


    --Write on the socket
    function self.Write( socket, message)
        if socket == self.Id then return end

        local data = deserialize(message) or {dat='[Unrecognized format]'.. message}
        
        local c = self.Connections[socket]
        
        print(socket .. ' : ' .. message)

        --Check if existing connection or listening
        if not c or not c.Handler then
            --if listening all
            if self.Connections["*"].Handler then
                if self.GetStatus( "*") == 'dead' then
                    self.Close( "*")
                    return
                end

                coroutine.resume( self.Connections["*"].Handler, data, socket)
            else          
                
                --Notify non listening
                print("Message received on '" .. socket .. "' socket. Was not listening.")
            end
        else
            if socket ~= 'ping' and data.rec ~= self.Id and data.rec ~= -1 then return end 

            --check if listener handler is dead
            if self.GetStatus( socket) == 'dead' then
                self.Close( socket)
                return
            end

            coroutine.resume( self.Connections[socket].Handler, data, socket)
        end

    end


    --Send transmission on socket
    function self.Send( socket, data, pck, ttl)
        local packet = {
            snd = self.Id,
            rec = socket or "",
            pck = pck or math.random(255),
            ttl = ttl or 1,
            dat = data
        }

        self.Emitter.send( self.Id, serialize(packet))
    end

    --=========================== Dispatching methods ==========================
    --Default dispatcher, just do nothing
    function _dispatch(socket)
        while true do
        	coroutine.yield()
        end
    end
    
    --Set a dispatcher function
    function self.SetDispatch( fnc)
        _dispatch = fnc
    end
    
    --=========================== Connection etablishment calls ==========================
    --======================= CLIENT =========================
    function _receiveSYN()
        local data, socket = {dat=""}, nil

        
        --While waiting ping answer
        while self.WaitPing do
            --Don't listen unrecognized format data
            while type(data.dat) ~= 'table' do
                data, socket = coroutine.yield()
            end

            local content = data.dat

            --Reception of the ping answer
            if content.SYN and not content.ACK then -- ONLY SYN

                --Create connection on the socket of the sender (senderId is the Socket)
                local c = self.CreateConnection( socket)
                c.SynKey = content.SYN

                c.Status = "SYN-RECEIVED"
                self.Listen( socket, _receiveACK)

                self.Send( socket, { SYN=_key, ACK=content.SYN+1})
            end

            data = {dat=""}
        end

        self.Close( "*")
    end


    function _receiveACK()
        local data, socket = {dat=""}, nil

        --While waiting ping answer
        while self.WaitPing do
            --Don't listen unrecognized format data
            while type(data.dat) ~= 'table' do
                data, socket = coroutine.yield()
            end

            local content = data.dat

            if not content.SYN and content.ACK then -- ONLY ACK
                --print("Received validation of the acknowledge from "..msg.snd)
                if content.ACK == _key+1 then
                    local c = self.Connections[socket]
                    c.AckKey = content.ACK

                    c.Status = "ETABLISHED"
                    c.Connected = true
                    print("Connection etablished to " .. socket )
                    
                    self.Listen( socket, _dispatch)
                end
            end

            data = {dat=""}
        end

        self.Close( socket)
    end


    function self.Ping()
        self.Close( "*")
        self.WaitPing = true

        self.ListenAll( _receiveSYN)
        self.Emitter.send( "ping",nil)
    end


    --======================= SERVER =========================    
    function _receiveSYNACK()
        local data, socket = {dat=""}, nil

        --While waiting ping answer
        while not self.WaitPing do
            --Don't listen unrecognized format data
            while type(data.dat) ~= 'table' do
                data, socket = coroutine.yield()
            end

            local content = data.dat

            --Received answer of a acknowledge
            if content.ACK and content.SYN then -- SYN & ACK                
                --print("Received answer of a acknowledge from"..msg.snd)
                if content.ACK == _key+1 then

                    local c = self.CreateConnection( socket)
                    c.SynKey = content.SYN
                    c.AckKey = content.ACK

                    c.Status = "ETABLISHED"
                    c.Connected = true
                    print("Connection etablished to " .. socket )
                    
                    self.Listen( socket, _dispatch)

                    self.Send( socket, { ACK=content.SYN+1})
                end
            end

            data = {dat=""}
        end

        self.Close( "*")
    end    


    function _receivePing()
        while true do
            local data = coroutine.yield()

            --if sent a ping, don't answer to our own ping
            if self.WaitPing then goto continue end

            self.Close( "*")
            self.ListenAll( _receiveSYNACK)

            self.Send( nil, { SYN=_key})

            ::continue::
        end
    end



    self.CreateConnection( "*")
    self.Listen( "ping", _receivePing)
    self.ListenAll( _receiveSYNACK)    

    --Send its key when started for the case it's started by an analogic signal from a receiver
    self.Send( nil, { SYN=_key})

    return self
end