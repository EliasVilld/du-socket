MySockets = Sockets( emitter, receiver)

function Dispatcher( socket)
    while true do
        local data = coroutine.yield()
        
        if data.rec ~= MySockets.Id then goto continue end
        
        local content = data.dat

        
        if content.cmd then
            if content.cmd == "close" then
                door.deactivate()
            elseif content.cmd == "open" then
                door.activate()
            elseif content.cmd == "disconnect" then
                MySockets.Close( socket)
                MySockets.Send( data.snd, {echo="timeout"})
                unit.exit()
            end
        else
            MySockets.Send( data.snd, data.dat, data.pck, data.ttl -1 )
        end
        
        ::continue::
    end
end
    
MySockets.SetDispatch( Dispatcher)
