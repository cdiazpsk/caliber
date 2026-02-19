import SignInForm from "@/components/sign-in-form";

export default function SignInPage() {
  return (
    <main
      className="container"
      style={{ minHeight: "100vh", display: "grid", placeItems: "center" }}
    >
      <SignInForm />
    </main>
  );
}
