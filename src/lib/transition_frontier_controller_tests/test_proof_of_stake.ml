open Async
open Core
open Cache_lib
open Pipe_lib

module Stubs = Stubs.Make (struct
  let max_length = 4
end)

open Stubs

(* [%%if
consensus_mechanism = "proof_of_stake"]
 *)
let%test_module "Proof of stake tests" =
  ( module struct
    let%test "update, update_var agree starting from same consensus state" =
      let open Consensus in
      let open Quickcheck.Let_syntax in
      let module Stubs =
        Coda_base.External_transition.Make
          (Staged_ledger_diff)
          (Consensus.Protocol_state)
      in
      Quickcheck.random_value
        (let gen_slot_advancement = Int.gen_incl 1 10 in
         let%bind make_consensus_state =
           For_tests.gen_consensus_state ~gen_slot_advancement
         in
         let previous_protocol_state = Consensus.genesis_protocol_state in
         let snarked_ledger_hash =
           previous_protocol_state |> With_hash.data
           |> Protocol_state.blockchain_state
           |> Protocol_state.Blockchain_state.snarked_ledger_hash
         in
         let consensus_state =
           make_consensus_state ~snarked_ledger_hash ~previous_protocol_state
         in
         let len, _, _, _, _, _ = consensus_state in
         return true)
  end )

(*  [%%endif] *)
