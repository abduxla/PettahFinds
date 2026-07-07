"use client";

import {
  createContext,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from "react";
import { onAuthStateChanged, signOut, type User } from "firebase/auth";
import { doc, onSnapshot } from "firebase/firestore";
import { auth, db } from "@/lib/firebase";
import { appUserFromDoc, type AppUser } from "@/lib/types";

/**
 * Session context for the whole portal.
 *
 * Mirrors the mobile app's auth chain (authStateProvider → appUserProvider):
 * Firebase Auth gives the identity; the live /users/{uid} doc gives the
 * role + businessId that drive routing. Both are subscriptions, so role
 * changes (e.g. an admin linking a business) propagate without re-login.
 */
interface AuthState {
  /** Raw Firebase user; null when signed out. */
  fbUser: User | null;
  /** The /users/{uid} profile; null until loaded or when signed out. */
  appUser: AppUser | null;
  /** True until BOTH auth state and the profile doc have resolved. */
  loading: boolean;
  signOutPortal: () => Promise<void>;
}

const AuthContext = createContext<AuthState>({
  fbUser: null,
  appUser: null,
  loading: true,
  signOutPortal: async () => {},
});

export function AuthProvider({ children }: { children: ReactNode }) {
  const [fbUser, setFbUser] = useState<User | null>(null);
  const [appUser, setAppUser] = useState<AppUser | null>(null);
  const [authResolved, setAuthResolved] = useState(false);
  const [profileResolved, setProfileResolved] = useState(false);

  useEffect(() => {
    return onAuthStateChanged(auth, (u) => {
      setFbUser(u);
      setAuthResolved(true);
      if (!u) {
        setAppUser(null);
        setProfileResolved(true);
      } else {
        setProfileResolved(false);
      }
    });
  }, []);

  useEffect(() => {
    if (!fbUser) return;
    return onSnapshot(
      doc(db, "users", fbUser.uid),
      (snap) => {
        setAppUser(appUserFromDoc(snap));
        setProfileResolved(true);
      },
      () => {
        // Profile unreadable (deleted account / rules) — treat as no profile.
        setAppUser(null);
        setProfileResolved(true);
      },
    );
  }, [fbUser]);

  const value: AuthState = {
    fbUser,
    appUser,
    loading: !authResolved || (fbUser !== null && !profileResolved),
    signOutPortal: () => signOut(auth),
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthState {
  return useContext(AuthContext);
}
