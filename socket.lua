function Sockets( emit, recv)
    assert(serialize,"Missing serialize library.")
    
    --Local declaration
    local self = {}
    local _key = math.random(255)
     
    --Properties
    self.Emitter = emit
    self.Receiver = recv
       
    self.WaitPing = false    
    self.Connections = {}
    
    --Core slot detection
    for k,v in pairs(unit) do
        if type(v) == 'table' and v.getElementClass then
            local class = v.getElementClass()

            if class:find('^CoreUnit') then core = v end
        end
    end
    assert(core,"Missing link with the Core Unit.")
    self.Id = tostring(core.getConstructId())
    
    
    --== Connection methods ==
    --Create connection
    function self.CreateConnection( socket)
        print('Connection creation : ' .. socket)
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

    
    --Clear all connections
    function self.ClearAllConnection()
        self.Connections = nil
    end


    -- Ping construct around
    function self.Ping()
        self.Close( "*")
        self.WaitPing = true

        self.ListenAll( _receiveSYN)
        self.Emitter.send( "ping",nil)
    end
    

    --== Socket methods ==
    --Create a listen handler on socket
    function self.Listen( socket, fnc)
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


    --Wait for data on the socket
    function self.Read()
        return coroutine.yield()
    end


    --Write on the socket
    function self.Write( socket, msg)
        if socket == self.Id then return end
        
        local data = deserialize(msg) or {dat='[Unrecognized format]'.. msg}
        
        local c = self.Connections[socket]
        
        print(socket .. ' : ' .. msg)

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
                
                --Notify transmission received but not listening
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
    function self.Send( socket, data, pcket, ttl)
        local packet = {
            snd = self.Id,
            rec = socket or "",
            pck = pck or math.random(255),
            ttl = ttl or 1,
            dat = data
        }

        self.Emitter.send( self.Id, serialize(packet))
    end

    
    --== Dispatching methods ==
    -- Default dispatching function
    function _dispatch(socket)
        while true do
        	coroutine.yield()
        end
    end
    
    -- Set a specific dispatcher function
    function self.SetDispatch( fnc)
        _dispatch = fnc
    end
    
    --== Triple hand shake connection methods ==
    --= Client side =
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


    --= Server side = 
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

    -- Ping handler
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


    -- Initialization
    -- Set broadcast receiving connection
    self.CreateConnection( "*")
    
    -- Set handler to receive ping
    self.Listen( "ping", _receivePing)
    
    -- Set the ping answer listener
    self.ListenAll( _receiveSYNACK)
    --Send the SYN key when started (in case it's started by an analogic signal)
    self.Send( nil, { SYN=_key})
    

    return self
end
