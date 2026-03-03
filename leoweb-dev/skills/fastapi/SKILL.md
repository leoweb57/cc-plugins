# FastAPI

## Description

FastAPI web framework with async patterns, Pydantic validation, and OpenAPI documentation.

## When to Use

- Building REST APIs with Python
- Async web applications
- OpenAPI/Swagger documentation needed

---

## Core Patterns

### Route Definition

```python
from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel

app = FastAPI()

class UserCreate(BaseModel):
    email: str
    name: str

class UserResponse(BaseModel):
    id: int
    email: str
    name: str

@app.post("/users", response_model=UserResponse, status_code=201)
async def create_user(user: UserCreate):
    # Create user logic
    return UserResponse(id=1, **user.model_dump())

@app.get("/users/{user_id}", response_model=UserResponse)
async def get_user(user_id: int):
    user = await get_user_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user
```

### Dependency Injection

```python
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with async_session_maker() as session:
        yield session

@app.get("/users")
async def list_users(db: AsyncSession = Depends(get_db)):
    return await db.execute(select(User))
```

### Router Organization

```python
from fastapi import APIRouter

router = APIRouter(prefix="/users", tags=["users"])

@router.get("/")
async def list_users():
    pass

# In main.py
app.include_router(router)
```

## Best Practices

1. Use Pydantic models for request/response validation
2. Organize routes with APIRouter
3. Use dependency injection for services
4. Return proper HTTP status codes
5. Add OpenAPI descriptions

## Common Pitfalls

- **Blocking I/O in async**: Use async libraries
- **Missing response models**: Always define them
- **No error handling**: Use HTTPException properly
