import { BomItem, BomSection } from "../api/engineeringData";

const EMPTY_ITEM: BomItem = {
  quantity: "",
  description: "",
  part_number: "",
  note: "",
};

export default function BomSectionEditor({
  section,
  onChange,
}: {
  section: BomSection;
  onChange: (updated: BomSection) => void;
}) {
  function updateItem(index: number, field: keyof BomItem, value: string) {
    const items = section.items.map((it, i) =>
      i === index ? { ...it, [field]: value } : it,
    );
    onChange({ ...section, items });
  }

  function addRow() {
    onChange({ ...section, items: [...section.items, { ...EMPTY_ITEM }] });
  }

  function removeRow(index: number) {
    onChange({ ...section, items: section.items.filter((_, i) => i !== index) });
  }

  return (
    <div>
      <div className="section-title">{section.title}</div>
      <table>
        <thead>
          <tr>
            <th style={{ width: "10%" }}>Qty</th>
            <th style={{ width: "38%", textAlign: "left" }}>Description</th>
            <th style={{ width: "22%" }}>Part number</th>
            <th style={{ width: "22%" }}>Note</th>
            <th style={{ width: "8%" }}></th>
          </tr>
        </thead>
        <tbody>
          {section.items.map((item, i) => (
            <tr key={i}>
              <td>
                <input
                  value={item.quantity}
                  onChange={(e) => updateItem(i, "quantity", e.target.value)}
                />
              </td>
              <td>
                <input
                  style={{ textAlign: "left" }}
                  value={item.description}
                  onChange={(e) => updateItem(i, "description", e.target.value)}
                />
              </td>
              <td>
                <input
                  value={item.part_number}
                  onChange={(e) => updateItem(i, "part_number", e.target.value)}
                />
              </td>
              <td>
                <input
                  value={item.note}
                  onChange={(e) => updateItem(i, "note", e.target.value)}
                />
              </td>
              <td>
                <button className="secondary" onClick={() => removeRow(i)}>
                  &times;
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      <button className="secondary" onClick={addRow}>
        + Add row
      </button>
    </div>
  );
}
