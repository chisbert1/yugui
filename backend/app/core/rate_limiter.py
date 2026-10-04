"""
app/core/rate_limiter.py
------------------------
Redis-backed rate limiting using fastapi-limiter.
Applied globally in main.py and can be overridden per-route.

Default limits:
  - Authenticated endpoints: 100 req/min per user
  - Sync trigger endpoints:  10 req/min per IP
  - Auth endpoints:          20 req/min per IP (brute-force protection)
"""

import hashlib

from fastapi import Request, Response
from fastapi_limiter import FastAPILimiter
from fastapi_limiter.depends import RateLimiter

from app.core.redis_client import get_redis


async def init_rate_limiter() -> None:
    """Call on FastAPI startup to connect FastAPILimiter to Redis."""
    redis = await get_redis()
    await FastAPILimiter.init(redis, identifier=_user_or_ip_identifier)


async def _user_or_ip_identifier(request: Request, response: Response) -> str:
    """
    Rate limit key strategy:
    - If the request has a valid JWT: limit by user ID (fair per-user limits)
    - Otherwise: limit by IP address (protects auth endpoints)
    """
    # Try to extract user from Bearer token header
    auth = request.headers.get("Authorization", "")
    if auth.startswith("Bearer "):
        token = auth[7:]
        # Use a hash of the token as the key (don't store raw JWTs in Redis)
        return f"user:{hashlib.sha256(token.encode()).hexdigest()[:16]}"

    # Fall back to client IP
    forwarded = request.headers.get("X-Forwarded-For")
    ip = forwarded.split(",")[0].strip() if forwarded else request.client.host
    return f"ip:{ip}"


# ── Pre-built limiter dependencies ────────────────────────────────────────────
# Import these directly in route decorators:
#   @router.get("/...", dependencies=[Depends(RateLimitDefault)])

RateLimitDefault  = RateLimiter(times=100, seconds=60)   # 100 req/min
RateLimitAuth     = RateLimiter(times=20,  seconds=60)   # 20 req/min (auth)
RateLimitSync     = RateLimiter(times=10,  seconds=60)   # 10 req/min (admin sync)
RateLimitStrict   = RateLimiter(times=5,   seconds=60)   # 5 req/min (scan fallback)
