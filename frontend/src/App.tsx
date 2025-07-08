import { Routes, Route } from "react-router-dom";
import Home from "./pages/Home/HomePage";
import NotFoundPage from "./pages/NotFound/NotFoundPage";

const App = () => {
  return (
    <Routes>
      <Route path="/" element={<Home />} />
      <Route path="*" element={<NotFoundPage />} />
    </Routes>
  );
};

export default App;
