(** This module combines a theory with a notion of stack to create interpreters.
*)

open Base
open Common

module Sigs = Sigs
module Make = Make
module Stack = Stack

exception ApplyOpsExc = Make.ApplyOpsExc

module Contracts (T : Theo.Sigs.Theory) : Sigs.ContractEnv with module Theory = T = struct
    module Theory = T

    type live = {
        address : Theory.Address.t ;
        contract : Contract.t ;
        mutable balance : Theory.Tez.t ;
        mutable storage : Theory.value ;
        params : Theory.contract_params ;
    }

    type t = {
        mutable defs : (string, Contract.t) Hashtbl.t ;
        mutable live : (int, live) Hashtbl.t ;
    }

    let empty () : t = { defs = Hashtbl.create 47 ; live = Hashtbl.create 47 }

    let add (contract : Contract.t) (self : t) : unit =
        if Hashtbl.mem self.defs contract.name then (
            asprintf "trying to register two contracts named `%s`" contract.Contract.name
            |> Exc.throw
        ) else (
            Hashtbl.add self.defs contract.name contract
        )

    let get (name : string) (self : t) : Contract.t =
        (fun () -> Hashtbl.find self.defs name)
        |> Exc.erase_err (
            fun () -> sprintf "could not find contract `%s`" name
        )

    module Live = struct
        let update
            (balance : Theory.Tez.t)
            ((storage, dtyp) : Theory.value * Dtyp.t)
            (address : Theory.Address.t)
            (self : t)
            : unit
        =
            let uid = Theory.Address.uid address in
            let live =
                try Hashtbl.find self.live uid with
                | Not_found ->
                    asprintf "cannot update contract at unknown address %a" Theory.Address.fmt address
                    |> Exc.throw
            in
            (fun () -> Dtyp.check dtyp live.contract.storage)
            |> Exc.chain_err (
                fun () -> asprintf "while updating storage at %a" Theory.Address.fmt address
            );
            live.balance <- balance;
            live.storage <- storage;
            ()

        let fmt (fmt: formatter) (self : t) : unit =
            fprintf fmt "@[<v>";
            Hashtbl.fold (
                fun _ live is_first ->
                    if not is_first then (
                        fprintf fmt "@ "
                    );
                    fprintf fmt "%s %a"
                        live.contract.name
                        Theory.Address.fmt live.address;
                    false
            ) self.live true
            |> ignore;
            fprintf fmt "@]"

        let count (self : t) : int = Hashtbl.length self.live

        let create
            (params : Theory.contract_params)
            (contract : Contract.t)
            (self : t)
        : unit =
            let address = params.address in
            let uid = Theory.Address.uid address in
            if Hashtbl.mem self.live uid then (
                [
                    asprintf "trying to create two contracts with address `%a`" Theory.Address.fmt address ;
                    asprintf "one called `%s`" contract.name ;
                    asprintf "another one called `%s`" (Hashtbl.find self.live uid).contract.name ;
                ] |> Exc.throws
            ) else (
                let deployed =
                    { address ; contract ; balance = params.tez ; storage = params.value ; params }
                in
                Hashtbl.add self.live uid deployed
            )

        let get (address : Theory.Address.t) (self : t) : live option =
            try Some (Hashtbl.find self.live (Theory.Address.uid address)) with
            | Not_found -> None

        let transfer (tez : Theory.Tez.t) (live : live) : unit =
            live.balance <- Theory.Tez.add live.balance tez
    end
end

module NaiveInterp = Make.Interpreter (Stack.Naive) ( Contracts(Stack.Naive.Theory) )