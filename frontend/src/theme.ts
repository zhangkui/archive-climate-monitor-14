// 图表/状态配色取自 dataviz 参考色板（亮模式）：
// 系列色固定顺序：蓝=温度、橙=湿度、青=露点；状态色保留，不挪作系列色。
export const series = {
  temp: "#2a78d6",
  humi: "#eb6834",
  dew: "#1baf7a"
} as const;

export const statusColor = {
  good: "#0ca30c",
  warning: "#fab219",
  serious: "#ec835a",
  critical: "#d03b3b",
  info: "#2a78d6"
} as const;

export const ink = {
  primary: "#0b0b0b",
  secondary: "#52514e",
  muted: "#898781",
  grid: "#e1e0d9",
  surface: "#fcfcfb",
  page: "#f9f9f7",
  border: "rgba(11,11,11,0.10)"
} as const;
