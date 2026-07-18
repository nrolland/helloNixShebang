#!/usr/bin/env rust-script
//! ```cargo
//! [dependencies]
//! num-integer = "=0.1.46"
//! ```

use num_integer::Integer;

fn main() {
    for n in 1..=9u64 {
        let label = if n.is_odd() { "odd" } else { "even" };
        println!("{}\t{}", n, label);
    }
}
