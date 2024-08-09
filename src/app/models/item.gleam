import gleam/option.{type Option}
import wisp

pub type ItemStatus {
  Completed
  Uncompleted
}

pub type Tag =
  String

pub type Item {
  Item(
    id: String,
    title: String,
    description: String,
    status: ItemStatus,
    tags: List(Tag),
  )
}

pub fn create_item(
  id: Option(String),
  title: String,
  description: String,
  completed: Bool,
  tags: List(Tag),
) -> Item {
  let id = option.unwrap(id, wisp.random_string(64))
  case completed {
    True -> Item(id, title, description, status: Completed, tags: tags)
    False -> Item(id, title, description, status: Uncompleted, tags: tags)
  }
}

pub fn toggle_todo(item: Item) -> Item {
  let new_status = case item.status {
    Completed -> Uncompleted
    Uncompleted -> Completed
  }
  Item(..item, status: new_status)
}

pub fn item_status_to_bool(status: ItemStatus) -> Bool {
  case status {
    Completed -> True
    Uncompleted -> False
  }
}
