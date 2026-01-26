from sqlalchemy.orm import Session

from app.models.client import Client
from app.schemas.client import ClientCreate, ClientUpdate


class ClientRepository:
    def __init__(self, db: Session):
        self.db = db

    def create(self, data: ClientCreate) -> Client:
        obj = Client(**data.model_dump())
        self.db.add(obj)
        self.db.commit()
        self.db.refresh(obj)
        return obj

    def get(self, client_id: int) -> Client | None:
        return self.db.get(Client, client_id)

    def list(self, skip: int = 0, limit: int = 50) -> list[Client]:
        return (
            self.db.query(Client)
            .order_by(Client.surname, Client.first_name)
            .offset(skip)
            .limit(limit)
            .all()
        )

    def update(self, client: Client, data: ClientUpdate) -> Client:
        for field, value in data.model_dump(exclude_unset=True).items():
            setattr(client, field, value)
        self.db.add(client)
        self.db.commit()
        self.db.refresh(client)
        return client

    def delete(self, client: Client) -> None:
        self.db.delete(client)
        self.db.commit()