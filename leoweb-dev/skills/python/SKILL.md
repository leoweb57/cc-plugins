# Python

## Description

Python development expertise including type hints, async patterns, virtual environments, and Pythonic idioms.

## When to Use

- Working with Python files (.py)
- Writing Python scripts or applications
- Using Python frameworks (Django, FastAPI, Flask)
- Data processing and automation

---

## Core Patterns

### Type Hints

```python
from typing import Optional, List, Dict, Union
from collections.abc import Callable

def process_items(
    items: List[str],
    callback: Callable[[str], None],
    config: Optional[Dict[str, Any]] = None
) -> List[str]:
    """Process items with optional callback."""
    return [callback(item) for item in items]
```

### Async/Await

```python
import asyncio
from typing import List

async def fetch_data(url: str) -> dict:
    async with aiohttp.ClientSession() as session:
        async with session.get(url) as response:
            return await response.json()

async def fetch_all(urls: List[str]) -> List[dict]:
    return await asyncio.gather(*[fetch_data(url) for url in urls])
```

### Context Managers

```python
from contextlib import contextmanager

@contextmanager
def managed_resource():
    resource = acquire_resource()
    try:
        yield resource
    finally:
        release_resource(resource)

# Usage
with managed_resource() as r:
    r.do_something()
```

### Dataclasses

```python
from dataclasses import dataclass, field
from datetime import datetime

@dataclass
class User:
    id: int
    email: str
    name: str
    created_at: datetime = field(default_factory=datetime.now)

    def __post_init__(self):
        self.email = self.email.lower()
```

### Pydantic Models

```python
from pydantic import BaseModel, EmailStr, Field

class UserCreate(BaseModel):
    email: EmailStr
    name: str = Field(min_length=1, max_length=100)
    password: str = Field(min_length=8)

    class Config:
        str_strip_whitespace = True
```

## Best Practices

1. Use type hints for all public functions
2. Use dataclasses or Pydantic for data models
3. Prefer context managers for resource management
4. Use async for I/O-bound operations
5. Follow PEP 8 style guidelines

## Common Pitfalls

- **Mutable default arguments**: Use `None` and initialize in function
- **Not closing resources**: Use `with` statements
- **Blocking in async**: Use `asyncio.to_thread()` for CPU work
- **Catching bare exceptions**: Be specific with exception types
