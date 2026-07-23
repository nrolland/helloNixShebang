use num_integer::Integer;

fn main() {
    for n in 1..=9u64 {
        let label = if n.is_odd() { "odd" } else { "even" };
        println!("{}\t{}", n, label);
    }
}
