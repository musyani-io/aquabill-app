from sqlalchemy.orm import Session

from app.models.client import Client
from app.repositories.client import ClientRepository
from app.schemas.client import ClientCreate, ClientUpdate


class ClientService:
    def __init__(self, db: Session):
        self.repo = ClientRepository(db)

    def create(self, data: ClientCreate) -> Client:
        return self.repo.create(data)

    def get(self, client_id: int) -> Client | None:
        return self.repo.get(client_id)

    def list(self, skip: int = 0, limit: int = 50) -> list[Client]:
        return self.repo.list(skip=skip, limit=limit)

    def update(self, client_id: int, data: ClientUpdate) -> Client | None:
        client = self.repo.get(client_id)
        if client is None:
            return None
        return self.repo.update(client, data)

    def delete(self, client_id: int) -> bool:
        client = self.repo.get(client_id)
        if client is None:
            return False
        self.repo.delete(client)
        return True
