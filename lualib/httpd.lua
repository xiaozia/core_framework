local tcp = require "internal.TCP"
local HTTP = require "protocol.http"

local tostring = tostring
local co_new = coroutine.create
local co_start = coroutine.resume
local co_wakeup = coroutine.resume
local co_suspend = coroutine.yield
local co_self = coroutine.running


-- 请求解析
local EVENT_DISPATCH = HTTP.EVENT_DISPATCH

-- 注册HTTP路由
local HTTP_ROUTE_REGISTERY = HTTP.ROUTE_REGISTERY

local class = require "class"

local httpd = class("httpd")

function httpd:ctor(opt)
	self.cos = {}
    self.routes = {}
    self.IO = nil
end

-- 用来注册Rest API
function httpd:api(route, class)
    if route and type(class) == "table" then
        HTTP_ROUTE_REGISTERY(self.routes, route, class, HTTP.API)
    end
end

-- 用来注册普通路由
function httpd:use(route, class)
    if route and type(class) == "table" then
        HTTP_ROUTE_REGISTERY(self.routes, route, class, HTTP.USE)
    end
end

function httpd:static(foldor, ttl)

end

-- 最大http request body长度
function httpd:set_max_body_size(body_size)
    if body_size and int(body_size) and int(body_size) > 0 then
        self._max_body_size = body_size
    end
end

-- 最大http request header长度
function httpd:set_max_header_size(header_size)
    if header_size and int(header_size) and int(header_size) > 0 then
        self._max_header_size = header_size
    end
end

function httpd:registery(co, fd, ipaddr)
	if type(co) == "thread" then
		self.cos[co] = {fd = fd, ipaddr = ipaddr}
	end
end

function httpd:unregistery(co)
	if type(co) == "thread" then
		self.cos[co] = nil
	end
end

function httpd:listen (ip, port)
	self.IO = tcp:new()
    self.accept_co = co_new(function (fd, ipaddr)
        while 1 do
        	if fd and ipaddr then
        		local ok, msg = co_start(co_new(function (fd, ipaddr)
                    local co = co_self()
                    -- 注册协程
                    self:registery(co, fd, ipaddr)
                    -- HTTP 生命周期
                    EVENT_DISPATCH(fd, self)
                    -- 清除协程
                    self:unregistery(co)
                end), fd, ipaddr)
        		if not ok then
        			print(msg)
        		end
        	end
            fd, ipaddr = co_suspend()
        end
    end)
    return self.IO:listen(ip, port, self.accept_co)
end

function httpd:start(ip, port)
	return self:listen(ip, port)
end

return httpd
