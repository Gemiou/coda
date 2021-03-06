(** Encrypted secrets.

[of_yojson] is the only constructor that takes in raw data.
General usage pattern:

{[
  let protected = Secret_box.encrypt ~password ~plaintext |> Secret_box.to_yojson |> Yojson.to_string in
  let maybe_unprotected = Secret_box.of_yojson protected |> Or_error.map ~f:(Secret_box.decrypt ~password) in
  assert maybe_unprotected = Ok plaintext
]}

{b NOTE:} this will _erase_ the contents of [password] arguments. If you stash them somewhere (you shouldn't outside of tests), you should copy the string before you call these functions.
*)

type t [@@deriving sexp, yojson]

module Stable : sig
  module V1 : sig
    type nonrec t = t [@@deriving sexp]
  end
end

val encrypt : password:Bytes.t -> plaintext:Bytes.t -> t
(** Password-protect some plaintext. *)

val decrypt : password:Bytes.t -> t -> Bytes.t Core.Or_error.t
(** Decrypt some bytes with a password *)
