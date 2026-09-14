export default function Placeholder({ name }: { name: string }) {
  return (
    <div>
      <h2>{name}</h2>
      <div className="card placeholder-card">
        Not ported yet. See the project README's roadmap for what's built
        vs. planned -- Busbar Check is the first complete vertical slice
        (calculation engine, API, PDF report, and this UI), used to prove
        the architecture before porting the remaining ~10 MATLAB domains.
      </div>
    </div>
  );
}
