import app/models/item.{type Item, create_item}
import app/web.{type Context, Context}
import gleam/dynamic
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import wisp.{type Request, type Response}

type Tag =
  String

type ItemsJson {
  ItemsJson(
    id: String,
    title: String,
    description: String,
    completed: Bool,
    tags: List(Tag),
  )
}

fn tags_string_to_list(tags: String) -> List(Tag) {
  case tags |> string.trim {
    "" -> []
    tags -> tags |> string.split(" ") |> list.unique()
  }
}

pub fn post_create_item(req: Request, ctx: Context) {
  use form <- wisp.require_form(req)

  let current_items = ctx.items

  let result = {
    use item_title <- result.try(list.key_find(form.values, "todo_title"))
    let item_description =
      result.unwrap(list.key_find(form.values, "todo_description"), "")
    let item_tags =
      result.unwrap(list.key_find(form.values, "todo_tags"), "")
      |> tags_string_to_list
    let new_item =
      create_item(None, item_title, item_description, False, item_tags)
    list.append(current_items, [new_item])
    |> todos_to_json
    |> Ok
  }

  case result {
    Ok(todos) -> {
      wisp.redirect("/")
      |> wisp.set_cookie(req, "items", todos, wisp.PlainText, 60 * 60 * 24)
    }
    Error(_) -> {
      wisp.bad_request()
    }
  }
}

pub fn delete_item(req: Request, ctx: Context, item_id: String) {
  let current_items = ctx.items

  let json_items = {
    list.filter(current_items, fn(item) { item.id != item_id })
    |> todos_to_json
  }
  wisp.redirect("/")
  |> wisp.set_cookie(req, "items", json_items, wisp.PlainText, 60 * 60 * 24)
}

pub fn delete_tag_from_item(
  req: Request,
  ctx: Context,
  item_id: String,
  tag_to_delete: Tag,
) {
  let current_items = ctx.items

  let result = {
    use _ <- result.try(
      list.find(current_items, fn(item) { item.id == item_id }),
    )
    current_items
    |> list.map(fn(item) {
      case item.id == item_id {
        True -> item.remove_tag_from_item(item, tag_to_delete)
        False -> item
      }
    })
    |> todos_to_json
    |> Ok
  }

  case result {
    Ok(json_items) ->
      wisp.redirect("/")
      |> wisp.set_cookie(req, "items", json_items, wisp.PlainText, 60 * 60 * 24)
    Error(_) -> wisp.bad_request()
  }
}

pub fn patch_toggle_todo(req: Request, ctx: Context, item_id: String) {
  let current_items = ctx.items

  let result = {
    use _ <- result.try(
      list.find(current_items, fn(item) { item.id == item_id }),
    )
    list.map(current_items, fn(item) {
      case item.id == item_id {
        True -> item.toggle_todo(item)
        False -> item
      }
    })
    |> todos_to_json
    |> Ok
  }

  case result {
    Ok(json_items) ->
      wisp.redirect("/")
      |> wisp.set_cookie(req, "items", json_items, wisp.PlainText, 60 * 60 * 24)
    Error(_) -> wisp.bad_request()
  }
}

pub fn items_middleware(
  req: Request,
  ctx: Context,
  handle_request: fn(Context) -> Response,
) {
  let parsed_items = {
    case wisp.get_cookie(req, "items", wisp.PlainText) {
      Ok(json_string) -> {
        let decoder =
          dynamic.decode5(
            ItemsJson,
            dynamic.field("id", dynamic.string),
            dynamic.field("title", dynamic.string),
            dynamic.field("description", dynamic.string),
            dynamic.field("completed", dynamic.bool),
            dynamic.field("tags", dynamic.list(dynamic.string)),
          )
          |> dynamic.list

        let result = json.decode(json_string, decoder)
        case result {
          Ok(items) -> items
          Error(_) -> []
        }
      }
      Error(_) -> []
    }
  }

  let items = create_items_from_json(parsed_items)

  let ctx = Context(..ctx, items: items)

  handle_request(ctx)
}

fn create_items_from_json(items: List(ItemsJson)) -> List(Item) {
  items
  |> list.map(fn(item) {
    let ItemsJson(id, title, description, completed, tags) = item
    create_item(Some(id), title, description, completed, tags)
  })
}

fn todos_to_json(items: List(Item)) -> String {
  "["
  <> items
  |> list.map(item_to_json)
  |> string.join(",")
  <> "]"
}

fn item_to_json(item: Item) -> String {
  json.object([
    #("id", json.string(item.id)),
    #("title", json.string(item.title)),
    #("description", json.string(item.description)),
    #("completed", json.bool(item.item_status_to_bool(item.status))),
    #("tags", json.array(item.tags, json.string)),
  ])
  |> json.to_string
}
