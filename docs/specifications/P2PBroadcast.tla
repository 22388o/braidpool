----------------------------- MODULE P2PBroadcast -----------------------------
(***************************************************************************)
(* The specification caputers the DAG based reliable broadcast to          *)
(* disseminate messages over a peer to peer network.                       *)
(*                                                                         *)
(* The broadcast enables nodes to know which nodes have revceived the      *)
(* message by using implicit acknowledgements.  The broadcast is not a BFT *)
(* broadcast.  We depend on the higher layers to provide that.             *)
(*                                                                         *)
(* Does this open this broadcast to a DDoS attack? Yes, and our argument   *)
(* remains that p2p network can resist DDoS attacks by other means.        *)
(*                                                                         *)
(* First pass - We assume no processes failures or messages lost.          *)
(***************************************************************************)

EXTENDS Naturals, Sequences

CONSTANT
            Proc,   \* Set of processes
            Data,
            Nbrs
             
VARIABLES
            channels,   \* All channels between nodes, can be indexed as
                        \* channels[from][to] and channels[to][from] and has a
                        \* queue of messages
            sent_by,    \* Function from message to all Proc that have sent it
            recv_at     \* Function from message to all Proc that have received it

vars == <<sent_by, recv_at, channels>>
------------------------------------------------------------------------------
Message == [from: Proc, data: Data]

Init == 
        /\ sent_by = [m \in Message |-> {}]
        /\ recv_at = [m \in Message |-> {}]
        /\ channels = [<<p, q>> \in Nbrs |-> <<>>]    \* Messages delivered in order

TypeInvariant ==
        /\ sent_by \in [Message -> SUBSET Proc]
        /\ recv_at \in [Message -> SUBSET Proc]
        /\ channels \in [Nbrs -> Seq(Message)]

------------------------------------------------------------------------------

(***************************************************************************)
(* SendTo(m, p) - send message m to neighbour p                            *)
(*                                                                         *)
(* Sending to self is required as then the message is in the recv list as  *)
(* well.                                                                   *)
(***************************************************************************)
SendTo(m, p) ==
            /\ m.from \notin sent_by[m] \* Don't send again - we can add decay here
            /\ <<m.from, p>> \in Nbrs   \* Send only to neighbours
            /\ sent_by' = [sent_by EXCEPT ![m] = @ \union {m.from}]
            /\ channels' = [channels EXCEPT ![<<m.from, p>>] = Append(@, m)]
            /\ UNCHANGED <<recv_at>>

(***************************************************************************)
(* RecvAt(m, q) - receive message m at q.  This can be received from       *)
(* forwards                                                                *)
(***************************************************************************)

RecvAt(m, p, q) ==
            /\ <<p, q>> \in Nbrs               \* receive only at neighbours
            /\ Len(channels[<<p, q>>]) > 0     \* receive if there is a message
            /\ m = Head(channels[<<p, q>>])    \* receive the message at head
            /\ \exists r \in Proc: r \in sent_by[m] \* Some process has sent the message
            /\ q \notin recv_at[m]                  \* Not already received by q
            /\ recv_at' = [recv_at EXCEPT ![m] = @ \union {q}]
            /\ channels' = [channels EXCEPT ![<<p, q>>] = Tail(@)]
            /\ UNCHANGED <<sent_by>>

(*
Lose(m, p, q) ==
            /\ Len(channels[<<m.from, q>>]) > 0
            /\ m = Head(channels[<<m.from, q>>])
            /\ channels' = [channels EXCEPT ![<<m.from, q>>] = Tail(@)]
            /\ UNCHANGED <<sent_by, recv_at>>
*)

(***************************************************************************)
(* Forward(m, p, q) - forward message m from p to q                        *)
(*                                                                         *)
(* Enabling condition - m has been sent by some process, q has received    *) 
(* the message, q is not the sender                                        *)
(*                                                                         *)
(* Effect - p forwards the message m to its nbrs                           *)
(***************************************************************************)

Forward(m, p, q) ==
            /\ \exists r \in Proc: r \in sent_by[m] \* Some process has sent the message
            /\ p # q                                \* Don't forward to self
            /\ m.from # p                           \* Sender doesnt forward
            /\ <<p, q>> \in Nbrs                    \* Forward only to neighbour
            /\ p \in recv_at[m]                     \* p has received m
            /\ p \notin sent_by[m]                  \* Don't forward again
            /\ sent_by' = [sent_by EXCEPT ![m] = @ \union {p}]
            /\ channels' = [channels EXCEPT ![<<p, q>>] = Append(@, m)]
            /\ UNCHANGED <<recv_at>>

Next == \exists p \in Proc, q \in Proc, m \in Message:
            \/ SendTo(m, p)
            \/ RecvAt(m, p, q)
\*            \/ Lose(m, p, q)
            \/ Forward(m, p, q)
-----------------------------------------------------------------------------
Spec == /\ Init
        /\ [][Next]_vars


SendLeadsToRecv == \A m \in Message: \A p \in sent_by: \A  q \in recv_at:
            (p \in sent_by[m] /\ p = m.from) ~> (q \in recv_at[m] \/ q # m.from)


(***************************************************************************)
(* Liveness specifies that if a message is enabled to be received at p, it *)
(* is eventually received at p.                                            *)
(***************************************************************************)
Liveness == \A p \in Proc: \A q \in Proc: \A m \in Message: SF_vars(RecvAt(m, p, q))

FairSpec == Spec /\ Liveness
-----------------------------------------------------------------------------
THEOREM Spec => []TypeInvariant
=============================================================================
\* Modification History
\* Last modified Wed Apr 05 06:29:25 CEST 2023 by kulpreet
\* Created Sun Mar 05 15:04:04 CET 2023 by kulpreet