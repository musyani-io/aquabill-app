from pydantic import BaseModel, Field


class ClientBase(BaseModel):
    first_name: str = Field(min_length=1, max_length=100)
    other_names: str | None = Field(default=None, max_length=100)
    surname: str = Field(min_length=1, max_length=100)
    phone_number: str = Field(min_length=1, max_length=20)
    client_code: str | None = Field(default=None, max_length=50)


class ClientCreate(ClientBase):
    pass


class ClientUpdate(BaseModel):
    first_name: str | None = Field(default=None, max_length=100)
    other_names: str | None = Field(default=None, max_length=100)
    surname: str | None = Field(default=None, max_length=100)
    phone_number: str | None = Field(default=None, max_length=20)
    client_code: str | None = Field(default=None, max_length=50)


class ClientRead(ClientBase):
    id: int

    class Config:
        from_attributes = True
