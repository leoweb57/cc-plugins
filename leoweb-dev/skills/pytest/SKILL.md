# pytest

## Description

Python testing with pytest including fixtures, parametrization, and mocking.

## When to Use

- Writing Python tests
- Test fixtures and setup
- Mocking dependencies

---

## Core Patterns

### Basic Tests

```python
import pytest

def test_addition():
    assert 1 + 1 == 2

def test_exception():
    with pytest.raises(ValueError, match="Invalid"):
        raise ValueError("Invalid input")
```

### Fixtures

```python
@pytest.fixture
def user():
    return User(id=1, name="Test")

@pytest.fixture
def db_session():
    session = create_session()
    yield session
    session.close()

def test_with_fixtures(user, db_session):
    db_session.add(user)
    assert user.id is not None
```

### Parametrization

```python
@pytest.mark.parametrize("input,expected", [
    ("hello", "HELLO"),
    ("world", "WORLD"),
    ("", ""),
])
def test_uppercase(input, expected):
    assert input.upper() == expected
```

### Mocking

```python
from unittest.mock import Mock, patch

def test_with_mock():
    service = Mock()
    service.get_user.return_value = {"id": 1}

    result = service.get_user(1)
    assert result["id"] == 1

@patch('module.external_api')
def test_with_patch(mock_api):
    mock_api.fetch.return_value = {"data": []}
    # Test code that uses external_api
```

## Best Practices

1. Use fixtures for test setup
2. Parametrize for multiple test cases
3. Mock external dependencies
4. Use descriptive test names
5. Keep tests independent

## Common Pitfalls

- **Shared state**: Use fresh fixtures
- **Over-mocking**: Only mock boundaries
- **Slow tests**: Use markers for slow tests
