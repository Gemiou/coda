open Async_kernel
open Core_kernel

(** [Constant.S] is a helper signature for passing constant values
 *  to functors.
 *)
module Constant = struct
  module type S = sig
    type t

    val t : t
  end
end

(** A [('t, 'cache_t) Cached.t] is a representation of a value
 *  stored in a cache, where ['t] is the type of the immediate
 *  value currently being stored, and ['cache_t] is the type
 *  of the value stored in the underlying cache. A [Cached.t] has
 *  semantics such that it can only be consumed once, and
 *  will track and handle the case where it is garbage collected
 *  before consumption. [Cached.t] values can be consumed either
 *  by transforming the value into another [Cached.t] with a
 *  different ['t] parameter, or by invalidating the [Cached.t],
 *  which removes it from the underlying cache.
 *)
module Cached = struct
  module type S = sig
    type ('t, 'cache_t) t

    val pure : 't -> ('t, _) t
    (** [pure v] returns a pure cached object with
     *  the value of [v]. Pure cached objects are used
     *  for unifying values with the [Cached.t] type for 
     *  convenience. Pure cached objects are not stored
     *  in a cache and cannot be consumed.
     *)

    val peek : ('t, _) t -> 't
    (** [peek c] inspects the value of [c] without consuming
     *  [c].
     *)

    val invalidate : ('t, _) t -> 't Or_error.t
    (** [invalidate c] removes the underlying cached value
     *  of [c] from its cache. [invalidate] will return an
     *  [Error] if the underlying cached value was not
     *  present in the cache.
     *)

    val was_consumed : (_, _) t -> bool

    val transform : ('t0, 'cache_t) t -> f:('t0 -> 't1) -> ('t1, 'cache_t) t
    (** [transform c ~f ~logger] maps the value of [c] over
     *  [f], consuming [c]. *)

    val sequence_deferred :
      ('t Deferred.t, 'cache_t) t -> ('t, 'cache_t) t Deferred.t
    (** [sequence_deferred c] lifts a deferred value from
     *  [c], returning a non deferred cached object in a
     *  deferred context. [c] is consumed.
     *)

    val sequence_result :
      (('t, 'e) Result.t, 'cache_t) t -> (('t, 'cache_t) t, 'e) Result.t
    (** [sequence_result] lifts a result value from
     *  [c], returning a result containing the raw
     *  cached value if the value of [c] was [Ok].
     *  Otherwise, an [Error] is returned and [c]
     *  is invalidated from the cache
     *)
  end
end

(**
 *  A ['a Cache.t] is a [Hash_set.t] baked cache abstraction which
 *  registers [('a, 'a) Cached.t] values.
 *)
module Cache = struct
  module type S = sig
    module Cached : Cached.S

    type 'elt t

    val name : _ t -> string

    val create :
         name:string
      -> logger:Logger.t
      -> (module Hash_set.Elt_plain with type t = 'elt)
      -> 'elt t

    val register : 'elt t -> 'elt -> ('elt, 'elt) Cached.t Or_error.t
    (** [register cache elt] add [elt] to [cache]. If [elt]
     *  already existed in [cache], an [Error] is returned.
     *  Otherwise, [Ok] is returned with a [Cached]
     *  representation of [elt].
     *)

    val mem : 'elt t -> 'elt -> bool

    val to_list : 'elt t -> 'elt list
  end
end

(** A [Transmuter] module transmutes some source value into
 *  some target value
 *)
module Transmuter = struct
  module type S = sig
    module Source : sig
      type t
    end

    module Target : Hash_set.Elt_plain

    val transmute : Source.t -> Target.t
  end
end

(** A [Transmuter_cache] module is a wrapper for a [Cache]
 *  module, except that a [Transmuter] module provides a
 *  layer of indirection to the values stored in the
 *  [Cache.t], transmuting values through the interface
 *  to provide a more abstract interface.
 *)
module Transmuter_cache = struct
  module type S = sig
    module Cached : Cached.S

    module Cache : Cache.S with module Cached := Cached

    type target

    type source

    type t = target Cache.t

    val create : logger:Logger.t -> t

    val register : t -> source -> (source, target) Cached.t Or_error.t

    val mem : t -> source -> bool
  end

  module type F = sig
    module Cached : Cached.S

    module Cache : Cache.S with module Cached := Cached

    module Make
        (Transmuter : Transmuter.S)
        (Name : Constant.S with type t := string) :
      S
      with module Cached := Cached
       and module Cache := Cache
       and type source = Transmuter.Source.t
       and type target = Transmuter.Target.t
  end
end

(** [Main.S] is the signature of the [Cache_lib] library. *)
module Main = struct
  module type S = sig
    module Cached : Cached.S

    module Cache : Cache.S with module Cached := Cached

    module Transmuter_cache :
      Transmuter_cache.F with module Cached := Cached and module Cache := Cache
  end
end
