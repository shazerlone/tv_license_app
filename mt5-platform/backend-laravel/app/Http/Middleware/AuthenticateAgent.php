<?php

namespace App\Http\Middleware;

use App\Models\VpsServer;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Authenticates a Windows Agent by its per-VPS bearer token and binds the
 * resolved VpsServer onto the request. Every agent endpoint is then scoped to
 * that server — an agent physically cannot read/write another VPS's rows.
 */
class AuthenticateAgent
{
    public function handle(Request $request, Closure $next): Response
    {
        $token = $request->bearerToken();

        if (! $token || ! ($server = VpsServer::findByAgentToken($token))) {
            return response()->json(['message' => 'Invalid agent token'], 401);
        }

        if ($server->status === 'disabled') {
            return response()->json(['message' => 'Server disabled'], 403);
        }

        // Bind for controllers: $request->attributes->get('vps_server').
        $request->attributes->set('vps_server', $server);

        return $next($request);
    }
}
