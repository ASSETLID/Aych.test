(* Contract type and helpers. *)

open Common

type signature = {
    name : string option ;
    entry_param : Dtyp.t ;
}

let fmt_sig (fmt : formatter) {
    name ; entry_param
} : unit =
    let name = unwrap_or "<anonymous>" name in
    fprintf
        fmt
        "@[<v>@[<v 4>contract sig %s {@,%a@]@,}@]"
        name Dtyp.fmt entry_param;

type t = {
    name : string ;
    storage : Dtyp.t ;
    entry_param : Dtyp.t ;
    entry : Mic.t ;
    init : Mic.t option ;
}

let mk
    (name : string)
    ~(storage : Dtyp.t)
    ~(entry_param : Dtyp.t)
    (entry : Mic.t)
    (init : Mic.t option)
    : t
= { name ; storage ; entry_param ; entry ; init }

let fmt (full : bool) (fmt : formatter) {
    name ; storage ; entry_param ; entry ; init
} : unit =
    fprintf
        fmt
        "@[<v>@[<v 4>contract %s {@,storage : %a@,entry_param : %a@,"
        name Dtyp.fmt storage Dtyp.fmt entry_param;
    (
        if full then (
            fprintf fmt "entry: @[%a@]@,init: " Mic.fmt entry;
            match init with
            | None -> fprintf fmt "none"
            | Some ins -> fprintf fmt "@[%a@]" Mic.fmt ins
        ) else (
            fprintf fmt "entry: ...@,init: ";
            match init with
            | None -> fprintf fmt "none"
            | Some _ -> fprintf fmt "..."
        )
    );
    fprintf fmt "@]@,}@]"

let name_of_file (s : string) : string =
    let bail () = sprintf "illegal contract file name `%s`" s |> Exc.throw in
    if 1 > String.length s then bail ();
    let s =
        let rec get_last = function
        | [ last ] -> last
        | [] -> bail ()
        | _ :: tail -> get_last tail
        in
        match String.split_on_char '/' s |> get_last |> String.split_on_char '.' with
        | [] -> bail ()
        | head :: _ -> head
    in
    let head = String.sub s 0 1 |> String.capitalize_ascii in
    let tail = String.sub s 1 ((String.length s) - 1) in
    head ^ tail