import isOdd from "npm:is-odd@3.0.1";

for (let n = 1; n <= 9; n++) {
  console.log(`${n}\t${isOdd(n) ? "odd" : "even"}`);
}
